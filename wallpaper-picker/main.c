#include <gdk-pixbuf/gdk-pixbuf.h>
#include <glib/gstdio.h>
#include <gtk/gtk.h>
#include <string.h>

#define APP_ID "com.erick.WallpaperPicker"
#define THUMB_WIDTH 100

static const gchar *video_extensions[] = {"mp4", "mkv", "webm",
                                          "mov", "avi", NULL};

typedef struct {
  gchar *path;
  gchar *thumbnail;
} Wallpaper;

typedef struct {
  GtkApplication parent_instance;
  gchar *directory;
  GPtrArray *wallpapers;
  GtkFlowBox *flow_box;
  GtkPicture *preview;
  GtkMediaStream *media_stream;
  guint preview_timeout_id;
} WallpaperPicker;

typedef struct {
  GtkApplicationClass parent_class;
} WallpaperPickerClass;

G_DEFINE_TYPE(WallpaperPicker, wallpaper_picker, GTK_TYPE_APPLICATION)

static gboolean has_video_extension(const gchar *path) {
  gchar *suffix =
      g_ascii_strdown(strrchr(path, '.') ? strrchr(path, '.') + 1 : "", -1);
  gboolean result = FALSE;
  for (const gchar **extension = video_extensions; *extension; extension++) {
    if (g_strcmp0(suffix, *extension) == 0) {
      result = TRUE;
      break;
    }
  }
  g_free(suffix);
  return result;
}

static gchar *thumbnail_path(const gchar *path) {
  gchar *key = g_compute_checksum_for_string(G_CHECKSUM_SHA256, path, -1);
  gchar *cache_dir =
      g_build_filename(g_get_user_cache_dir(), "wallpaper-picker", NULL);
  g_mkdir_with_parents(cache_dir, 0700);
  gchar *result = g_strdup_printf("%s/%s.png", cache_dir, key);
  g_free(cache_dir);
  g_free(key);
  return result;
}

static gchar *make_video_thumbnail(const gchar *path) {
  gchar *thumbnail = thumbnail_path(path);
  if (g_file_test(thumbnail, G_FILE_TEST_EXISTS))
    return thumbnail;

  gchar *argv[] = {(gchar *)"ffmpeg",
                   (gchar *)"-y",
                   (gchar *)"-hide_banner",
                   (gchar *)"-loglevel",
                   (gchar *)"error",
                   (gchar *)"-ss",
                   (gchar *)"1",
                   (gchar *)"-i",
                   (gchar *)path,
                   (gchar *)"-frames:v",
                   (gchar *)"1",
                   (gchar *)"-vf",
                   (gchar *)"scale=240:-2",
                   thumbnail,
                   NULL};
  gint exit_status = 0;
  GError *error = NULL;
  if (!g_spawn_sync(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, NULL,
                    NULL, &exit_status, &error) ||
      !g_spawn_check_wait_status(exit_status, NULL)) {
    g_warning("Could not create thumbnail for %s: %s", path,
              error ? error->message : "ffmpeg failed");
    g_clear_error(&error);
    g_remove(thumbnail);
    g_free(thumbnail);
    return NULL;
  }
  return thumbnail;
}

static void wallpaper_free(gpointer data) {
  Wallpaper *wallpaper = data;
  g_free(wallpaper->path);
  g_free(wallpaper->thumbnail);
  g_free(wallpaper);
}

static gint compare_wallpapers(gconstpointer a, gconstpointer b) {
  const Wallpaper *left = *(Wallpaper *const *)a;
  const Wallpaper *right = *(Wallpaper *const *)b;
  return g_ascii_strcasecmp(left->path, right->path);
}

static void load_wallpapers(WallpaperPicker *picker) {
  GDir *directory = g_dir_open(picker->directory, 0, NULL);
  if (!directory)
    return;

  const gchar *name;
  while ((name = g_dir_read_name(directory))) {
    gchar *path = g_build_filename(picker->directory, name, NULL);
    if (!g_file_test(path, G_FILE_TEST_IS_REGULAR)) {
      g_free(path);
      continue;
    }

    gchar *thumbnail = NULL;
    if (has_video_extension(path)) {
      thumbnail = make_video_thumbnail(path);
    } else if (gdk_pixbuf_get_file_info(path, NULL, NULL)) {
      thumbnail = g_strdup(path);
    }

    if (thumbnail) {
      Wallpaper *wallpaper = g_new0(Wallpaper, 1);
      wallpaper->path = path;
      wallpaper->thumbnail = thumbnail;
      g_ptr_array_add(picker->wallpapers, wallpaper);
    } else {
      g_free(path);
    }
  }
  g_dir_close(directory);
  g_ptr_array_sort(picker->wallpapers, compare_wallpapers);
}

static GtkWidget *wallpaper_widget(Wallpaper *wallpaper) {
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
  gtk_widget_set_size_request(box, 100, 90);

  GtkWidget *picture = gtk_picture_new_for_filename(wallpaper->thumbnail);
  gtk_picture_set_content_fit(GTK_PICTURE(picture), GTK_CONTENT_FIT_CONTAIN);
  gtk_widget_set_size_request(picture, THUMB_WIDTH, 60);
  gtk_widget_set_halign(picture, GTK_ALIGN_FILL);
  gtk_widget_set_valign(picture, GTK_ALIGN_FILL);
  gtk_widget_set_hexpand(picture, TRUE);
  gtk_widget_set_vexpand(picture, TRUE);
  gtk_box_append(GTK_BOX(box), picture);

  return box;
}

static gboolean on_key_pressed(GtkEventControllerKey *controller, guint keyval,
                               guint keycode, GdkModifierType state,
                               gpointer user_data) {
  (void)controller;
  (void)keycode;
  WallpaperPicker *picker = user_data;

  if (keyval == GDK_KEY_Escape) {
    g_application_quit(G_APPLICATION(picker));
    return TRUE;
  }
  if (!(state & GDK_CONTROL_MASK) ||
      (keyval != GDK_KEY_n && keyval != GDK_KEY_p))
    return FALSE;

  GList *selected = gtk_flow_box_get_selected_children(picker->flow_box);
  GtkFlowBoxChild *current = selected ? selected->data : NULL;
  gint index = current ? gtk_flow_box_child_get_index(current) : 0;
  gint next = index + (keyval == GDK_KEY_n ? 1 : -1);
  if (next < 0)
    next = picker->wallpapers->len - 1;
  else if (next >= (gint)picker->wallpapers->len)
    next = 0;

  GtkFlowBoxChild *child =
      gtk_flow_box_get_child_at_index(picker->flow_box, next);
  if (child) {
    gtk_flow_box_select_child(picker->flow_box, child);
    gtk_widget_grab_focus(GTK_WIDGET(child));
  }
  g_list_free(selected);
  return TRUE;
}

static void update_preview(WallpaperPicker *picker) {
  GList *selected = gtk_flow_box_get_selected_children(picker->flow_box);
  GtkFlowBoxChild *child = selected ? selected->data : NULL;
  if (!child) {
    g_list_free(selected);
    return;
  }

  Wallpaper *wallpaper = g_object_get_data(G_OBJECT(child), "wallpaper");
  g_clear_object(&picker->media_stream);
  if (has_video_extension(wallpaper->path)) {
    GFile *file = g_file_new_for_path(wallpaper->path);
    picker->media_stream = gtk_media_file_new_for_file(file);
    gtk_media_stream_set_muted(picker->media_stream, TRUE);
    gtk_media_stream_set_loop(picker->media_stream, TRUE);
    gtk_picture_set_paintable(picker->preview,
                              GDK_PAINTABLE(picker->media_stream));
    gtk_media_stream_play(picker->media_stream);
    g_object_unref(file);
  } else {
    gtk_picture_set_filename(picker->preview, wallpaper->thumbnail);
  }
  g_list_free(selected);
}

static void on_window_width_changed(GObject *object, GParamSpec *pspec,
                                    gpointer user_data) {
  (void)pspec;
  GtkWidget *window = GTK_WIDGET(object);
  GtkWidget *wallpaper_list = user_data;
  gint width = gtk_widget_get_width(window);
  if (width > 0)
    gtk_widget_set_size_request(wallpaper_list, width / 10, -1);
}

static gboolean update_preview_delayed(gpointer user_data) {
  WallpaperPicker *picker = user_data;
  picker->preview_timeout_id = 0;
  update_preview(picker);
  return G_SOURCE_REMOVE;
}

static void on_selection_changed(GtkFlowBox *flow_box, gpointer user_data) {
  (void)flow_box;
  WallpaperPicker *picker = user_data;
  if (picker->preview_timeout_id)
    g_source_remove(picker->preview_timeout_id);
  picker->preview_timeout_id =
      g_timeout_add(250, update_preview_delayed, picker);
}

static void on_wallpaper_activated(GtkFlowBox *flow_box, GtkFlowBoxChild *child,
                                   gpointer user_data) {
  (void)flow_box;
  Wallpaper *wallpaper = g_object_get_data(G_OBJECT(child), "wallpaper");
  g_print("%s\n", wallpaper->path);
  g_application_quit(G_APPLICATION(user_data));
}

static void wallpaper_picker_activate(GApplication *application) {
  WallpaperPicker *picker = (WallpaperPicker *)application;
  if (!picker->directory) {
    g_printerr("Usage: wallpaper-picker DIRECTORY\n");
    g_application_quit(application);
    return;
  }

  load_wallpapers(picker);
  if (picker->wallpapers->len == 0) {
    g_printerr("No supported images or videos found in '%s'\n",
               picker->directory);
    g_application_quit(application);
    return;
  }

  GtkWidget *window = gtk_application_window_new(GTK_APPLICATION(application));
  gtk_window_set_title(GTK_WINDOW(window), "Wallpaper Picker");
  gtk_window_set_default_size(GTK_WINDOW(window), 1200, 760);

  GtkWidget *main_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
  gtk_widget_set_margin_start(main_box, 16);
  gtk_widget_set_margin_end(main_box, 16);
  gtk_widget_set_margin_top(main_box, 16);
  gtk_widget_set_margin_bottom(main_box, 16);
  gtk_window_set_child(GTK_WINDOW(window), main_box);

  GtkWidget *content = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 16);
  gtk_widget_set_vexpand(content, TRUE);
  gtk_box_append(GTK_BOX(main_box), content);

  GtkEventController *keys = gtk_event_controller_key_new();
  g_signal_connect(keys, "key-pressed", G_CALLBACK(on_key_pressed), picker);
  gtk_widget_add_controller(window, keys);

  GtkWidget *scrolled = gtk_scrolled_window_new();
  gtk_widget_set_size_request(scrolled, 120, -1);
  gtk_widget_set_hexpand(scrolled, FALSE);
  gtk_widget_set_vexpand(scrolled, TRUE);
  gtk_box_append(GTK_BOX(content), scrolled);

  picker->flow_box = GTK_FLOW_BOX(gtk_flow_box_new());
  gtk_flow_box_set_selection_mode(picker->flow_box, GTK_SELECTION_SINGLE);
  gtk_flow_box_set_activate_on_single_click(picker->flow_box, FALSE);
  gtk_flow_box_set_max_children_per_line(picker->flow_box, 1);
  gtk_flow_box_set_min_children_per_line(picker->flow_box, 1);
  gtk_flow_box_set_column_spacing(picker->flow_box, 12);
  gtk_flow_box_set_row_spacing(picker->flow_box, 12);
  gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled),
                                GTK_WIDGET(picker->flow_box));

  GtkWidget *preview_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  gtk_widget_set_size_request(preview_box, 420, -1);
  gtk_widget_set_hexpand(preview_box, FALSE);
  gtk_box_append(GTK_BOX(content), preview_box);

  picker->preview = GTK_PICTURE(gtk_picture_new());
  gtk_picture_set_content_fit(picker->preview, GTK_CONTENT_FIT_CONTAIN);
  gtk_picture_set_can_shrink(picker->preview, TRUE);
  gtk_widget_set_size_request(GTK_WIDGET(picker->preview), 420, -1);
  gtk_widget_set_hexpand(GTK_WIDGET(picker->preview), FALSE);
  gtk_widget_set_vexpand(GTK_WIDGET(picker->preview), TRUE);
  gtk_box_append(GTK_BOX(preview_box), GTK_WIDGET(picker->preview));

  GtkWidget *hint = gtk_label_new(
      "Arrow keys to navigate · Enter to select · Escape to cancel");
  gtk_widget_add_css_class(hint, "dim-label");
  gtk_box_append(GTK_BOX(main_box), hint);

  for (guint i = 0; i < picker->wallpapers->len; i++) {
    Wallpaper *wallpaper = g_ptr_array_index(picker->wallpapers, i);
    GtkWidget *child = gtk_flow_box_child_new();
    gtk_flow_box_child_set_child(GTK_FLOW_BOX_CHILD(child),
                                 wallpaper_widget(wallpaper));
    g_object_set_data(G_OBJECT(child), "wallpaper", wallpaper);
    gtk_flow_box_append(picker->flow_box, child);
  }

  g_signal_connect(window, "notify::width", G_CALLBACK(on_window_width_changed),
                   scrolled);
  on_window_width_changed(G_OBJECT(window), NULL, scrolled);

  g_signal_connect(picker->flow_box, "selected-children-changed",
                   G_CALLBACK(on_selection_changed), picker);
  g_signal_connect(picker->flow_box, "child-activated",
                   G_CALLBACK(on_wallpaper_activated), picker);
  gtk_flow_box_select_child(
      picker->flow_box, gtk_flow_box_get_child_at_index(picker->flow_box, 0));
  gtk_window_present(GTK_WINDOW(window));
}

static void wallpaper_picker_open(GApplication *application, GFile **files,
                                  gint n_files, const gchar *hint) {
  (void)hint;
  WallpaperPicker *picker = (WallpaperPicker *)application;
  if (n_files > 0) {
    g_free(picker->directory);
    picker->directory = g_file_get_path(files[0]);
  }
  wallpaper_picker_activate(application);
}

static void wallpaper_picker_finalize(GObject *object) {
  WallpaperPicker *picker = (WallpaperPicker *)object;
  g_free(picker->directory);
  g_clear_object(&picker->media_stream);
  g_ptr_array_unref(picker->wallpapers);
  G_OBJECT_CLASS(wallpaper_picker_parent_class)->finalize(object);
}

static void wallpaper_picker_class_init(WallpaperPickerClass *class) {
  GObjectClass *object_class = G_OBJECT_CLASS(class);
  object_class->finalize = wallpaper_picker_finalize;
}

static void wallpaper_picker_init(WallpaperPicker *picker) {
  picker->wallpapers = g_ptr_array_new_with_free_func(wallpaper_free);
}

int main(int argc, char **argv) {
  WallpaperPicker *picker =
      g_object_new(wallpaper_picker_get_type(), "application-id", APP_ID,
                   "flags", G_APPLICATION_HANDLES_OPEN, NULL);
  g_signal_connect(picker, "activate", G_CALLBACK(wallpaper_picker_activate),
                   NULL);
  g_signal_connect(picker, "open", G_CALLBACK(wallpaper_picker_open), NULL);
  int status = g_application_run(G_APPLICATION(picker), argc, argv);
  g_object_unref(picker);
  return status;
}
