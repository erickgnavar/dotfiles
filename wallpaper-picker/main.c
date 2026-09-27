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
  GdkTexture *small_texture;
  GdkTexture *preview_texture;
  gboolean preview_loading;
  GWeakRef picture;
} Wallpaper;

typedef struct {
  GtkApplication parent_instance;
  gchar *directory;
  GWeakRef window;
  guint window_generation;
  GPtrArray *wallpapers;
  GDir *wallpaper_dir;
  GQueue *pending_paths;
  GQueue *preview_cache;
  gboolean scan_complete;
  guint scan_source_id;
  GtkFlowBox *flow_box;
  GtkPicture *preview;
  GtkMediaStream *media_stream;
  guint video_preview_timeout_id;
  guint prefetch_timeout_id;
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
  gchar *cache_key = g_strconcat(path, ":full-resolution-v1", NULL);
  gchar *key = g_compute_checksum_for_string(G_CHECKSUM_SHA256, cache_key, -1);
  g_free(cache_key);
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
  g_clear_object(&wallpaper->small_texture);
  g_clear_object(&wallpaper->preview_texture);
  g_weak_ref_clear(&wallpaper->picture);
  g_free(wallpaper);
}

static gint compare_wallpaper_children(GtkFlowBoxChild *a, GtkFlowBoxChild *b,
                                       gpointer user_data) {
  (void)user_data;
  Wallpaper *left = g_object_get_data(G_OBJECT(a), "wallpaper");
  Wallpaper *right = g_object_get_data(G_OBJECT(b), "wallpaper");
  return g_ascii_strcasecmp(left->path, right->path);
}

static GtkWidget *wallpaper_widget(Wallpaper *wallpaper) {
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
  gtk_widget_set_size_request(box, 100, 90);

  GtkWidget *picture = gtk_picture_new();
  g_weak_ref_set(&wallpaper->picture, G_OBJECT(picture));
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

static gboolean play_video_preview(gpointer user_data) {
  WallpaperPicker *picker = user_data;
  picker->video_preview_timeout_id = 0;

  GList *selected = gtk_flow_box_get_selected_children(picker->flow_box);
  GtkFlowBoxChild *child = selected ? selected->data : NULL;
  Wallpaper *wallpaper =
      child ? g_object_get_data(G_OBJECT(child), "wallpaper") : NULL;
  if (wallpaper && has_video_extension(wallpaper->path)) {
    GFile *file = g_file_new_for_path(wallpaper->path);
    picker->media_stream = gtk_media_file_new_for_file(file);
    gtk_media_stream_set_muted(picker->media_stream, TRUE);
    gtk_media_stream_set_loop(picker->media_stream, TRUE);
    gtk_picture_set_paintable(picker->preview,
                              GDK_PAINTABLE(picker->media_stream));
    gtk_media_stream_play(picker->media_stream);
    g_object_unref(file);
  }
  g_list_free(selected);
  return G_SOURCE_REMOVE;
}

typedef struct {
  gchar *path;
  Wallpaper *wallpaper;
  guint window_generation;
} PreviewRequest;

static void preview_request_free(gpointer data) {
  PreviewRequest *request = data;
  g_free(request->path);
  g_free(request);
}

static void load_preview_async(GTask *task, gpointer source_object,
                               gpointer task_data, GCancellable *cancellable) {
  (void)source_object;
  (void)cancellable;
  PreviewRequest *request = task_data;
  GdkPixbuf *pixbuf = gdk_pixbuf_new_from_file(request->path, NULL);
  g_task_return_pointer(task, pixbuf, g_object_unref);
}

static void load_preview_finished(GObject *source_object, GAsyncResult *result,
                                  gpointer user_data) {
  (void)user_data;
  WallpaperPicker *picker = (WallpaperPicker *)source_object;
  PreviewRequest *request = g_task_get_task_data(G_TASK(result));
  GdkPixbuf *pixbuf = g_task_propagate_pointer(G_TASK(result), NULL);
  GtkWindow *window = g_weak_ref_get(&picker->window);
  if (!window || request->window_generation != picker->window_generation) {
    g_clear_object(&window);
    g_clear_object(&pixbuf);
    return;
  }
  g_object_unref(window);
  request->wallpaper->preview_loading = FALSE;
  GList *selected = gtk_flow_box_get_selected_children(picker->flow_box);
  GtkFlowBoxChild *child = selected ? selected->data : NULL;
  gint index = child ? gtk_flow_box_child_get_index(child) : -1;
  gboolean current = child && g_object_get_data(G_OBJECT(child), "wallpaper") ==
                                  request->wallpaper;
  gboolean nearby = current;
  for (gint offset = -1; index >= 0 && offset <= 1; offset += 2) {
    GtkFlowBoxChild *neighbor =
        gtk_flow_box_get_child_at_index(picker->flow_box, index + offset);
    if (neighbor && g_object_get_data(G_OBJECT(neighbor), "wallpaper") ==
                        request->wallpaper)
      nearby = TRUE;
  }
  if (pixbuf && nearby) {
    GBytes *bytes = gdk_pixbuf_read_pixel_bytes(pixbuf);
    GdkMemoryFormat format = gdk_pixbuf_get_has_alpha(pixbuf)
                                 ? GDK_MEMORY_R8G8B8A8
                                 : GDK_MEMORY_R8G8B8;
    GdkTexture *texture = gdk_memory_texture_new(
        gdk_pixbuf_get_width(pixbuf), gdk_pixbuf_get_height(pixbuf), format,
        bytes, gdk_pixbuf_get_rowstride(pixbuf));
    g_bytes_unref(bytes);
    request->wallpaper->preview_texture = texture;
    g_queue_push_tail(picker->preview_cache, request->wallpaper);
    if (g_queue_get_length(picker->preview_cache) > 3) {
      Wallpaper *old = g_queue_pop_head(picker->preview_cache);
      g_clear_object(&old->preview_texture);
    }
    if (current && !picker->media_stream)
      gtk_picture_set_paintable(picker->preview, GDK_PAINTABLE(texture));
  }
  g_list_free(selected);
  if (pixbuf)
    g_object_unref(pixbuf);
}

static void start_preview_load(WallpaperPicker *picker, Wallpaper *wallpaper,
                               gint priority) {
  if (!wallpaper->thumbnail || wallpaper->preview_texture ||
      wallpaper->preview_loading)
    return;
  PreviewRequest *request = g_new0(PreviewRequest, 1);
  request->path = g_strdup(wallpaper->thumbnail);
  request->wallpaper = wallpaper;
  request->window_generation = picker->window_generation;
  wallpaper->preview_loading = TRUE;
  GTask *task = g_task_new(picker, NULL, load_preview_finished, NULL);
  g_task_set_task_data(task, request, preview_request_free);
  g_task_set_priority(task, priority);
  g_task_run_in_thread(task, load_preview_async);
  g_object_unref(task);
}

static void update_preview(WallpaperPicker *picker) {
  GList *selected = gtk_flow_box_get_selected_children(picker->flow_box);
  GtkFlowBoxChild *child = selected ? selected->data : NULL;
  if (!child) {
    g_list_free(selected);
    return;
  }

  Wallpaper *wallpaper = g_object_get_data(G_OBJECT(child), "wallpaper");
  gtk_picture_set_paintable(picker->preview,
                            wallpaper->preview_texture
                                ? GDK_PAINTABLE(wallpaper->preview_texture)
                                : NULL);
  if (wallpaper->preview_texture) {
    g_queue_remove(picker->preview_cache, wallpaper);
    g_queue_push_tail(picker->preview_cache, wallpaper);
  } else if (wallpaper->thumbnail) {
    start_preview_load(picker, wallpaper, G_PRIORITY_HIGH);
  }
  if (has_video_extension(wallpaper->path))
    picker->video_preview_timeout_id =
        g_timeout_add(600, play_video_preview, picker);
  g_list_free(selected);
}

typedef struct {
  gchar *thumbnail;
  GdkPixbuf *pixbuf;
} ThumbnailResult;

static void thumbnail_result_free(gpointer data) {
  ThumbnailResult *result = data;
  g_free(result->thumbnail);
  g_clear_object(&result->pixbuf);
  g_free(result);
}

static void load_thumbnail_async(GTask *task, gpointer source_object,
                                 gpointer task_data,
                                 GCancellable *cancellable) {
  (void)source_object;
  (void)cancellable;
  Wallpaper *wallpaper = task_data;
  ThumbnailResult *result = g_new0(ThumbnailResult, 1);
  result->thumbnail = wallpaper->thumbnail
                          ? g_strdup(wallpaper->thumbnail)
                          : make_video_thumbnail(wallpaper->path);
  if (result->thumbnail)
    result->pixbuf = gdk_pixbuf_new_from_file_at_scale(
        result->thumbnail, THUMB_WIDTH * 2, 120, TRUE, NULL);
  g_task_return_pointer(task, result, thumbnail_result_free);
}

static void load_thumbnail_finished(GObject *source_object,
                                    GAsyncResult *result, gpointer user_data) {
  (void)user_data;
  WallpaperPicker *picker = (WallpaperPicker *)source_object;
  Wallpaper *wallpaper = g_task_get_task_data(G_TASK(result));
  ThumbnailResult *thumbnail = g_task_propagate_pointer(G_TASK(result), NULL);
  GtkWindow *window = g_weak_ref_get(&picker->window);
  if (!window || GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(result),
                                                    "window-generation")) !=
                     picker->window_generation) {
    g_clear_object(&window);
    if (thumbnail)
      thumbnail_result_free(thumbnail);
    return;
  }
  g_object_unref(window);
  if (!thumbnail)
    return;

  if (thumbnail->thumbnail && !wallpaper->thumbnail) {
    wallpaper->thumbnail = thumbnail->thumbnail;
    thumbnail->thumbnail = NULL;
  }
  if (thumbnail->pixbuf) {
    GBytes *bytes = gdk_pixbuf_read_pixel_bytes(thumbnail->pixbuf);
    GdkMemoryFormat format = gdk_pixbuf_get_has_alpha(thumbnail->pixbuf)
                                 ? GDK_MEMORY_R8G8B8A8
                                 : GDK_MEMORY_R8G8B8;
    wallpaper->small_texture = gdk_memory_texture_new(
        gdk_pixbuf_get_width(thumbnail->pixbuf),
        gdk_pixbuf_get_height(thumbnail->pixbuf), format, bytes,
        gdk_pixbuf_get_rowstride(thumbnail->pixbuf));
    g_bytes_unref(bytes);
    GtkPicture *picture = g_weak_ref_get(&wallpaper->picture);
    if (picture) {
      gtk_picture_set_paintable(picture,
                                GDK_PAINTABLE(wallpaper->small_texture));
      g_object_unref(picture);
    }
  }

  GList *selected = gtk_flow_box_get_selected_children(picker->flow_box);
  GtkFlowBoxChild *child = selected ? selected->data : NULL;
  if (child && g_object_get_data(G_OBJECT(child), "wallpaper") == wallpaper &&
      !picker->media_stream) {
    if (wallpaper->thumbnail && has_video_extension(wallpaper->path) &&
        !wallpaper->preview_loading && !wallpaper->preview_texture)
      start_preview_load(picker, wallpaper, G_PRIORITY_HIGH);
  }
  g_list_free(selected);
  thumbnail_result_free(thumbnail);
}

static gboolean prefetch_adjacent(gpointer user_data) {
  WallpaperPicker *picker = user_data;
  picker->prefetch_timeout_id = 0;
  GList *selected = gtk_flow_box_get_selected_children(picker->flow_box);
  GtkFlowBoxChild *child = selected ? selected->data : NULL;
  if (child) {
    gint index = gtk_flow_box_child_get_index(child);
    for (gint offset = -1; offset <= 1; offset += 2) {
      GtkFlowBoxChild *neighbor =
          gtk_flow_box_get_child_at_index(picker->flow_box, index + offset);
      if (neighbor) {
        Wallpaper *wallpaper =
            g_object_get_data(G_OBJECT(neighbor), "wallpaper");
        start_preview_load(picker, wallpaper, G_PRIORITY_LOW);
      }
    }
  }
  g_list_free(selected);
  return G_SOURCE_REMOVE;
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

static void on_selection_changed(GtkFlowBox *flow_box, gpointer user_data) {
  (void)flow_box;
  WallpaperPicker *picker = user_data;
  if (!picker->flow_box)
    return;
  if (picker->video_preview_timeout_id) {
    g_source_remove(picker->video_preview_timeout_id);
    picker->video_preview_timeout_id = 0;
  }
  if (picker->prefetch_timeout_id)
    g_source_remove(picker->prefetch_timeout_id);
  g_clear_object(&picker->media_stream);
  update_preview(picker);
  picker->prefetch_timeout_id = g_timeout_add(150, prefetch_adjacent, picker);
}

static void on_wallpaper_activated(GtkFlowBox *flow_box, GtkFlowBoxChild *child,
                                   gpointer user_data) {
  (void)flow_box;
  Wallpaper *wallpaper = g_object_get_data(G_OBJECT(child), "wallpaper");
  g_print("%s\n", wallpaper->path);
  g_application_quit(G_APPLICATION(user_data));
}

static void add_wallpaper(WallpaperPicker *picker, gchar *path,
                          gchar *thumbnail) {
  Wallpaper *wallpaper = g_new0(Wallpaper, 1);
  wallpaper->path = path;
  wallpaper->thumbnail = thumbnail;
  g_weak_ref_init(&wallpaper->picture, NULL);
  g_ptr_array_add(picker->wallpapers, wallpaper);

  GtkWidget *child = gtk_flow_box_child_new();
  gtk_flow_box_child_set_child(GTK_FLOW_BOX_CHILD(child),
                               wallpaper_widget(wallpaper));
  g_object_set_data(G_OBJECT(child), "wallpaper", wallpaper);
  gtk_flow_box_append(picker->flow_box, child);
  if (picker->wallpapers->len == 1)
    gtk_flow_box_select_child(picker->flow_box, GTK_FLOW_BOX_CHILD(child));

  GTask *task = g_task_new(picker, NULL, load_thumbnail_finished, NULL);
  g_object_set_data(G_OBJECT(task), "window-generation",
                    GUINT_TO_POINTER(picker->window_generation));
  g_task_set_task_data(task, wallpaper, NULL);
  g_task_run_in_thread(task, load_thumbnail_async);
  g_object_unref(task);
}

static gboolean scan_wallpapers(gpointer user_data) {
  WallpaperPicker *picker = user_data;
  GtkWindow *window = g_weak_ref_get(&picker->window);
  if (!window) {
    picker->scan_source_id = 0;
    return G_SOURCE_REMOVE;
  }
  g_object_unref(window);
  if (!picker->scan_complete && !picker->wallpaper_dir) {
    picker->wallpaper_dir = g_dir_open(picker->directory, 0, NULL);
    if (!picker->wallpaper_dir) {
      picker->scan_source_id = 0;
      g_printerr("Could not open wallpaper directory '%s'\n",
                 picker->directory);
      g_application_quit(G_APPLICATION(picker));
      return G_SOURCE_REMOVE;
    }
  }

  if (!picker->scan_complete) {
    for (guint i = 0; i < 8; i++) {
      const gchar *name = g_dir_read_name(picker->wallpaper_dir);
      if (!name) {
        g_dir_close(picker->wallpaper_dir);
        picker->wallpaper_dir = NULL;
        picker->scan_complete = TRUE;
        break;
      }

      gchar *path = g_build_filename(picker->directory, name, NULL);
      if (!g_file_test(path, G_FILE_TEST_IS_REGULAR)) {
        g_free(path);
        continue;
      }

      if (has_video_extension(path)) {
        gchar *thumbnail = thumbnail_path(path);
        if (g_file_test(thumbnail, G_FILE_TEST_EXISTS)) {
          add_wallpaper(picker, path, thumbnail);
          continue;
        }
        g_free(thumbnail);
        g_queue_push_tail(picker->pending_paths, path);
      } else if (gdk_pixbuf_get_file_info(path, NULL, NULL)) {
        add_wallpaper(picker, path, g_strdup(path));
      } else {
        g_free(path);
      }
    }
    return G_SOURCE_CONTINUE;
  }

  for (guint i = 0; i < 8 && !g_queue_is_empty(picker->pending_paths); i++) {
    gchar *path = g_queue_pop_head(picker->pending_paths);
    add_wallpaper(picker, path, NULL);
  }

  if (g_queue_is_empty(picker->pending_paths)) {
    picker->scan_source_id = 0;
    if (picker->wallpapers->len == 0) {
      g_printerr("No supported images or videos found in '%s'\n",
                 picker->directory);
      g_application_quit(G_APPLICATION(picker));
    }
    return G_SOURCE_REMOVE;
  }
  return G_SOURCE_CONTINUE;
}

static gboolean on_window_close_request(GtkWindow *window, gpointer user_data) {
  WallpaperPicker *picker = user_data;
  GtkWindow *current = g_weak_ref_get(&picker->window);
  gboolean active = current == window;
  g_clear_object(&current);
  if (!active)
    return FALSE;

  g_weak_ref_set(&picker->window, NULL);
  picker->window_generation++;
  picker->flow_box = NULL;
  picker->preview = NULL;
  if (picker->scan_source_id) {
    g_source_remove(picker->scan_source_id);
    picker->scan_source_id = 0;
  }
  if (picker->wallpaper_dir) {
    g_dir_close(picker->wallpaper_dir);
    picker->wallpaper_dir = NULL;
  }
  if (picker->video_preview_timeout_id) {
    g_source_remove(picker->video_preview_timeout_id);
    picker->video_preview_timeout_id = 0;
  }
  if (picker->prefetch_timeout_id) {
    g_source_remove(picker->prefetch_timeout_id);
    picker->prefetch_timeout_id = 0;
  }
  g_clear_object(&picker->media_stream);
  return FALSE;
}

static void wallpaper_picker_activate(GApplication *application) {
  WallpaperPicker *picker = (WallpaperPicker *)application;
  GtkWindow *existing = g_weak_ref_get(&picker->window);
  if (existing) {
    gtk_window_present(existing);
    g_object_unref(existing);
    return;
  }
  if (!picker->directory) {
    g_printerr("Usage: wallpaper-picker DIRECTORY\n");
    g_application_quit(application);
    return;
  }

  GtkWidget *window = gtk_application_window_new(GTK_APPLICATION(application));
  g_weak_ref_set(&picker->window, window);
  picker->window_generation++;
  g_signal_connect(window, "close-request", G_CALLBACK(on_window_close_request),
                   picker);
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
  gtk_flow_box_set_sort_func(picker->flow_box, compare_wallpaper_children, NULL,
                             NULL);
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

  g_signal_connect(window, "notify::width", G_CALLBACK(on_window_width_changed),
                   scrolled);
  on_window_width_changed(G_OBJECT(window), NULL, scrolled);

  g_signal_connect(picker->flow_box, "selected-children-changed",
                   G_CALLBACK(on_selection_changed), picker);
  g_signal_connect(picker->flow_box, "child-activated",
                   G_CALLBACK(on_wallpaper_activated), picker);
  gtk_window_present(GTK_WINDOW(window));
  picker->scan_source_id = g_timeout_add(10, scan_wallpapers, picker);
}

static void wallpaper_picker_open(GApplication *application, GFile **files,
                                  gint n_files, const gchar *hint) {
  (void)hint;
  WallpaperPicker *picker = (WallpaperPicker *)application;
  GtkWindow *existing = g_weak_ref_get(&picker->window);
  if (existing) {
    gtk_window_present(existing);
    g_object_unref(existing);
    return;
  }
  if (n_files > 0) {
    g_free(picker->directory);
    picker->directory = g_file_get_path(files[0]);
  }
  wallpaper_picker_activate(application);
}

static void wallpaper_picker_finalize(GObject *object) {
  WallpaperPicker *picker = (WallpaperPicker *)object;
  g_weak_ref_clear(&picker->window);
  g_free(picker->directory);
  if (picker->scan_source_id)
    g_source_remove(picker->scan_source_id);
  if (picker->wallpaper_dir)
    g_dir_close(picker->wallpaper_dir);
  g_queue_free_full(picker->pending_paths, g_free);
  g_queue_free(picker->preview_cache);
  if (picker->video_preview_timeout_id)
    g_source_remove(picker->video_preview_timeout_id);
  if (picker->prefetch_timeout_id)
    g_source_remove(picker->prefetch_timeout_id);
  g_clear_object(&picker->media_stream);
  g_ptr_array_unref(picker->wallpapers);
  G_OBJECT_CLASS(wallpaper_picker_parent_class)->finalize(object);
}

static void wallpaper_picker_class_init(WallpaperPickerClass *class) {
  GObjectClass *object_class = G_OBJECT_CLASS(class);
  object_class->finalize = wallpaper_picker_finalize;
}

static void wallpaper_picker_init(WallpaperPicker *picker) {
  g_weak_ref_init(&picker->window, NULL);
  picker->wallpapers = g_ptr_array_new_with_free_func(wallpaper_free);
  picker->pending_paths = g_queue_new();
  picker->preview_cache = g_queue_new();
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
