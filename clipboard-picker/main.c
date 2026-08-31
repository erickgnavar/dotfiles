#include <errno.h>
#include <gio/gio.h>
#include <gtk/gtk.h>
#include <json-glib/json-glib.h>
#include <stddef.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/un.h>
#include <unistd.h>

#define APP_ID "com.erick.ClipboardPicker"
#define PREVIEW_DEBOUNCE_MS 100
#define SEARCH_PREVIEW_DEBOUNCE_MS 200
#define PREVIEW_CACHE_MAX_ITEMS 12
#define PREVIEW_CACHE_MAX_BYTES (16 * 1024 * 1024)
#define SEARCH_CACHE_MAX_ENTRIES 32

typedef struct {
  GObject parent_instance;
  gchar *raw;
  gchar *display_single_line;
  gchar *search_text;
  gboolean binary;
} ClipboardItem;

typedef struct {
  GObjectClass parent_class;
} ClipboardItemClass;

typedef struct {
  gchar *key;
  GBytes *bytes;
  gsize size;
} PreviewCacheEntry;

typedef struct {
  int fd;
  guint generation;
} FocusedAppRequest;

typedef struct {
  GtkApplication parent_instance;
  GListStore *results;
  GPtrArray *search_items;
  GHashTable *search_cache;
  GtkSingleSelection *selection;
  GtkSearchEntry *search;
  GtkBox *preview_box;
  GtkStack *preview_stack;
  GtkLabel *empty_label;
  GtkPicture *picture;
  GtkLabel *text_preview;
  GtkLabel *mime_value;
  GtkLabel *size_value;
  GtkLabel *details_value;
  GtkListView *list_view;
  GtkWindow *window;
  gchar *focused_app;
  gchar *pending_query;
  guint preview_timeout_id;
  guint paste_timeout_id;
  guint secondary_setup_id;
  guint history_refresh_id;
  ClipboardItem *pending_preview_item;
  ClipboardItem *displayed_preview_item;
  GCancellable *focused_app_cancellable;
  GCancellable *history_cancellable;
  GSubprocess *history_process;
  GCancellable *preview_cancellable;
  GSubprocess *preview_process;
  GCancellable *paste_cancellable;
  GSubprocess *paste_process;
  GHashTable *preview_cache;
  GQueue preview_cache_lru;
  gsize preview_cache_bytes;
  guint focused_app_generation;
  guint preview_generation;
  gboolean history_loading;
  gboolean updating_results;
  gboolean shutting_down;
} ClipboardPicker;

typedef struct {
  GtkApplicationClass parent_class;
} ClipboardPickerClass;

G_DEFINE_TYPE(ClipboardItem, clipboard_item, G_TYPE_OBJECT)
G_DEFINE_TYPE(ClipboardPicker, clipboard_picker, GTK_TYPE_APPLICATION)

static void on_search_activate(GtkSearchEntry *search, gpointer user_data);
static void update_search_results(ClipboardPicker *app);

static gboolean write_all(int fd, const void *buffer, size_t size) {
  const guint8 *data = buffer;
  while (size > 0) {
    ssize_t written = write(fd, data, size);
    if (written < 0 && errno == EINTR)
      continue;
    if (written <= 0)
      return FALSE;
    data += written;
    size -= written;
  }
  return TRUE;
}

static gboolean read_all(int fd, void *buffer, size_t size) {
  guint8 *data = buffer;
  while (size > 0) {
    ssize_t received = read(fd, data, size);
    if (received < 0 && errno == EINTR)
      continue;
    if (received <= 0)
      return FALSE;
    data += received;
    size -= received;
  }
  return TRUE;
}

static gchar *focused_app_from_json(JsonNode *node) {
  if (!JSON_NODE_HOLDS_OBJECT(node))
    return NULL;

  JsonObject *object = json_node_get_object(node);
  if (json_object_has_member(object, "focused") &&
      json_object_get_boolean_member(object, "focused")) {
    const gchar *app_id = json_object_has_member(object, "app_id")
                              ? json_object_get_string_member(object, "app_id")
                              : NULL;
    if (app_id && *app_id)
      return g_strdup(app_id);

    JsonObject *properties =
        json_object_get_object_member(object, "window_properties");
    if (properties) {
      const gchar *class_name =
          json_object_has_member(properties, "class")
              ? json_object_get_string_member(properties, "class")
              : NULL;
      if (class_name && *class_name)
        return g_strdup(class_name);
    }
  }

  const gchar *child_names[] = {"nodes", "floating_nodes", NULL};
  for (const gchar **name = child_names; *name; name++) {
    JsonArray *children = json_object_get_array_member(object, *name);
    if (!children)
      continue;
    for (guint i = 0; i < json_array_get_length(children); i++) {
      gchar *result =
          focused_app_from_json(json_array_get_element(children, i));
      if (result)
        return result;
    }
  }
  return NULL;
}

static int begin_focused_app_request(void) {
  const gchar *socket_path = g_getenv("SWAYSOCK");
  if (!socket_path || !*socket_path)
    return -1;

  int fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd < 0)
    return -1;

  struct timeval timeout = {.tv_sec = 2};
  setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
  setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

  struct sockaddr_un address = {.sun_family = AF_UNIX};
  if (strlen(socket_path) >= sizeof(address.sun_path)) {
    close(fd);
    return -1;
  }
  g_strlcpy(address.sun_path, socket_path, sizeof(address.sun_path));
  if (connect(fd, (struct sockaddr *)&address,
              G_STRUCT_OFFSET(struct sockaddr_un, sun_path) +
                  strlen(socket_path) + 1) < 0) {
    close(fd);
    return -1;
  }

  const guint8 magic[] = {'i', '3', '-', 'i', 'p', 'c'};
  const guint32 payload_length = GUINT32_TO_LE(0);
  const guint32 message_type = GUINT32_TO_LE(4); /* GET_TREE */
  guint8 header[14];
  memcpy(header, magic, sizeof(magic));
  memcpy(header + 6, &payload_length, sizeof(payload_length));
  memcpy(header + 10, &message_type, sizeof(message_type));
  if (!write_all(fd, header, sizeof(header))) {
    close(fd);
    return -1;
  }
  return fd;
}

static gchar *read_focused_app_response(int fd) {
  const guint8 magic[] = {'i', '3', '-', 'i', 'p', 'c'};
  guint8 response_header[14];
  if (!read_all(fd, response_header, sizeof(response_header)) ||
      memcmp(response_header, magic, sizeof(magic)) != 0)
    return NULL;

  guint32 response_length = 0;
  memcpy(&response_length, response_header + 6, sizeof(response_length));
  response_length = GUINT32_FROM_LE(response_length);
  gchar *payload = g_malloc(response_length + 1);
  gchar *result = NULL;
  if (read_all(fd, payload, response_length)) {
    payload[response_length] = '\0';
    JsonParser *parser = json_parser_new();
    GError *error = NULL;
    if (json_parser_load_from_data(parser, payload, response_length, &error))
      result = focused_app_from_json(json_parser_get_root(parser));
    g_clear_error(&error);
    g_object_unref(parser);
  }
  g_free(payload);
  return result;
}

static void focused_app_request_free(gpointer data) {
  FocusedAppRequest *request = data;
  close(request->fd);
  g_free(request);
}

static void focused_app_task(GTask *task, gpointer source_object,
                             gpointer task_data, GCancellable *cancellable) {
  (void)source_object;
  (void)cancellable;
  FocusedAppRequest *request = task_data;
  if (g_task_return_error_if_cancelled(task))
    return;

  gchar *result = read_focused_app_response(request->fd);
  if (g_task_return_error_if_cancelled(task)) {
    g_free(result);
    return;
  }
  if (result) {
    gchar *normalized = g_ascii_strdown(result, -1);
    g_free(result);
    result = normalized;
  }
  g_task_return_pointer(task, result, g_free);
}

static void focused_app_loaded(GObject *source, GAsyncResult *result,
                               gpointer user_data) {
  (void)user_data;
  ClipboardPicker *app = (ClipboardPicker *)source;
  GTask *task = G_TASK(result);
  FocusedAppRequest *request = g_task_get_task_data(task);
  GError *error = NULL;
  gchar *focused_app = g_task_propagate_pointer(task, &error);

  if (request->generation == app->focused_app_generation) {
    g_clear_object(&app->focused_app_cancellable);
    if (!error && !app->shutting_down) {
      g_free(app->focused_app);
      app->focused_app = g_steal_pointer(&focused_app);
    }
  }
  g_free(focused_app);
  g_clear_error(&error);
}

static void load_focused_app_async(ClipboardPicker *app) {
  app->focused_app_generation++;
  if (app->focused_app_cancellable) {
    g_cancellable_cancel(app->focused_app_cancellable);
    g_clear_object(&app->focused_app_cancellable);
  }
  g_clear_pointer(&app->focused_app, g_free);

  int fd = begin_focused_app_request();
  if (fd < 0)
    return;

  FocusedAppRequest *request = g_new0(FocusedAppRequest, 1);
  request->fd = fd;
  request->generation = app->focused_app_generation;
  app->focused_app_cancellable = g_cancellable_new();
  GTask *task =
      g_task_new(app, app->focused_app_cancellable, focused_app_loaded, NULL);
  g_task_set_task_data(task, request, focused_app_request_free);
  g_task_run_in_thread(task, focused_app_task);
  g_object_unref(task);
}

static void clipboard_item_finalize(GObject *object) {
  ClipboardItem *item = (ClipboardItem *)object;
  g_free(item->raw);
  g_free(item->display_single_line);
  g_free(item->search_text);
  G_OBJECT_CLASS(clipboard_item_parent_class)->finalize(object);
}

static void clipboard_item_class_init(ClipboardItemClass *class) {
  G_OBJECT_CLASS(class)->finalize = clipboard_item_finalize;
}

static void clipboard_item_init(ClipboardItem *item) { (void)item; }

static void search_cache_reset(ClipboardPicker *app) {
  g_hash_table_remove_all(app->search_cache);
  g_hash_table_insert(app->search_cache, g_strdup(""),
                      g_ptr_array_ref(app->search_items));
}

static void search_cache_prune(ClipboardPicker *app, const gchar *query) {
  GHashTableIter iter;
  gpointer key;
  g_hash_table_iter_init(&iter, app->search_cache);
  while (g_hash_table_iter_next(&iter, &key, NULL)) {
    const gchar *cached_query = key;
    if (!g_str_has_prefix(query, cached_query))
      g_hash_table_iter_remove(&iter);
  }
}

static GPtrArray *search_cache_find_candidates(ClipboardPicker *app) {
  GPtrArray *best = app->search_items;
  gsize best_length = 0;
  GHashTableIter iter;
  gpointer key;
  gpointer value;
  g_hash_table_iter_init(&iter, app->search_cache);
  while (g_hash_table_iter_next(&iter, &key, &value)) {
    const gchar *cached_query = key;
    gsize cached_length = strlen(cached_query);
    if (cached_length >= best_length) {
      best = value;
      best_length = cached_length;
    }
  }
  return best;
}

static void search_cache_insert(ClipboardPicker *app, const gchar *query,
                                GPtrArray *matches) {
  g_hash_table_replace(app->search_cache, g_strdup(query),
                       g_ptr_array_ref(matches));

  while (g_hash_table_size(app->search_cache) > SEARCH_CACHE_MAX_ENTRIES) {
    const gchar *shortest_query = NULL;
    gsize shortest_length = G_MAXSIZE;
    GHashTableIter iter;
    gpointer key;
    g_hash_table_iter_init(&iter, app->search_cache);
    while (g_hash_table_iter_next(&iter, &key, NULL)) {
      const gchar *cached_query = key;
      gsize cached_length = strlen(cached_query);
      if (cached_length > 0 && cached_length < shortest_length) {
        shortest_query = cached_query;
        shortest_length = cached_length;
      }
    }
    g_hash_table_remove(app->search_cache, shortest_query);
  }
}

static void preview_cache_entry_free(PreviewCacheEntry *entry) {
  g_free(entry->key);
  g_bytes_unref(entry->bytes);
  g_free(entry);
}

static GBytes *preview_cache_lookup(ClipboardPicker *app, const gchar *key) {
  PreviewCacheEntry *entry = g_hash_table_lookup(app->preview_cache, key);
  if (!entry)
    return NULL;

  g_queue_remove(&app->preview_cache_lru, entry);
  g_queue_push_head(&app->preview_cache_lru, entry);
  return g_bytes_ref(entry->bytes);
}

static void preview_cache_insert(ClipboardPicker *app, const gchar *key,
                                 GBytes *bytes) {
  gsize size = g_bytes_get_size(bytes);
  if (size > PREVIEW_CACHE_MAX_BYTES)
    return;

  PreviewCacheEntry *entry = g_hash_table_lookup(app->preview_cache, key);
  if (entry) {
    GBytes *replacement = g_bytes_ref(bytes);
    app->preview_cache_bytes -= entry->size;
    g_clear_pointer(&entry->bytes, g_bytes_unref);
    entry->bytes = replacement;
    entry->size = size;
    app->preview_cache_bytes += size;
    g_queue_remove(&app->preview_cache_lru, entry);
    g_queue_push_head(&app->preview_cache_lru, entry);
  } else {
    entry = g_new0(PreviewCacheEntry, 1);
    entry->key = g_strdup(key);
    entry->bytes = g_bytes_ref(bytes);
    entry->size = size;
    app->preview_cache_bytes += size;
    g_hash_table_insert(app->preview_cache, entry->key, entry);
    g_queue_push_head(&app->preview_cache_lru, entry);
  }

  while (g_queue_get_length(&app->preview_cache_lru) >
             PREVIEW_CACHE_MAX_ITEMS ||
         app->preview_cache_bytes > PREVIEW_CACHE_MAX_BYTES) {
    entry = g_queue_pop_tail(&app->preview_cache_lru);
    app->preview_cache_bytes -= entry->size;
    g_hash_table_remove(app->preview_cache, entry->key);
    preview_cache_entry_free(entry);
  }
}

static void preview_cache_clear(ClipboardPicker *app) {
  PreviewCacheEntry *entry;
  while ((entry = g_queue_pop_head(&app->preview_cache_lru))) {
    g_hash_table_remove(app->preview_cache, entry->key);
    preview_cache_entry_free(entry);
  }
  app->preview_cache_bytes = 0;
}

static GBytes *decode_item(ClipboardItem *item) {
  const gchar *argv[] = {"cliphist", "decode", NULL};
  GSubprocessFlags flags = G_SUBPROCESS_FLAGS_STDIN_PIPE |
                           G_SUBPROCESS_FLAGS_STDOUT_PIPE |
                           G_SUBPROCESS_FLAGS_STDERR_PIPE;
  GSubprocess *process = g_subprocess_newv(argv, flags, NULL);
  if (!process)
    return NULL;

  GBytes *input = g_bytes_new(item->raw, strlen(item->raw));
  GBytes *stdout_data = NULL;
  GBytes *stderr_data = NULL;
  gboolean ok = g_subprocess_communicate(process, input, NULL, &stdout_data,
                                         &stderr_data, NULL);
  g_bytes_unref(input);
  if (!ok)
    g_clear_pointer(&stdout_data, g_bytes_unref);
  if (stderr_data) {
    gsize size = 0;
    const gchar *data = g_bytes_get_data(stderr_data, &size);
    if (size)
      g_debug("command: %.*s", (int)size, data);
    g_bytes_unref(stderr_data);
  }
  g_object_unref(process);
  return stdout_data;
}

static void parse_history_task(GTask *task, gpointer source_object,
                               gpointer task_data, GCancellable *cancellable) {
  (void)source_object;
  (void)cancellable;
  GBytes *output = task_data;
  gsize output_size = 0;
  const gchar *output_data = g_bytes_get_data(output, &output_size);
  gchar *text = g_malloc(output_size + 1);
  if (output_size)
    memcpy(text, output_data, output_size);
  text[output_size] = '\0';

  GPtrArray *items = g_ptr_array_new_with_free_func(g_object_unref);
  gchar *line_start = text;
  gchar *text_end = text + output_size;
  for (gchar *cursor = text;; cursor++) {
    if (cursor < text_end && *cursor != '\n')
      continue;

    *cursor = '\0';
    gchar *tab = memchr(line_start, '\t', cursor - line_start);
    if (tab && tab != line_start) {
      *tab = '\0';
      const gchar *display = tab + 1;
      ClipboardItem *item = g_object_new(clipboard_item_get_type(), NULL);
      item->raw = g_strdup(line_start);
      item->display_single_line = g_strdup(display);
      item->search_text = g_utf8_casefold(display, -1);
      item->binary = g_str_has_prefix(display, "[[ binary data");
      g_ptr_array_add(items, item);
    }
    if (cursor == text_end)
      break;
    line_start = cursor + 1;
  }

  g_free(text);
  g_task_return_pointer(task, items, (GDestroyNotify)g_ptr_array_unref);
}

static void history_parsed(GObject *source, GAsyncResult *result,
                           gpointer user_data) {
  (void)user_data;
  ClipboardPicker *app = (ClipboardPicker *)source;
  app->history_loading = FALSE;
  GPtrArray *items = g_task_propagate_pointer(G_TASK(result), NULL);
  if (app->shutting_down) {
    g_ptr_array_unref(items);
    return;
  }

  g_clear_pointer(&app->search_items, g_ptr_array_unref);
  app->search_items = items;
  search_cache_reset(app);

  if (app->search_items->len == 0)
    gtk_label_set_text(app->empty_label, "Clipboard history is empty");
  else
    gtk_label_set_text(app->empty_label, "Select an entry to preview");
  update_search_results(app);
}

static void history_loaded(GObject *source, GAsyncResult *result,
                           gpointer user_data) {
  ClipboardPicker *app = user_data;
  GSubprocess *process = G_SUBPROCESS(source);
  GBytes *output = NULL;
  GError *error = NULL;
  gboolean success =
      g_subprocess_communicate_finish(process, result, &output, NULL, &error);

  g_clear_object(&app->history_process);
  g_clear_object(&app->history_cancellable);
  g_object_unref(process);

  if (!success) {
    app->history_loading = FALSE;
    if (!app->shutting_down)
      gtk_label_set_text(app->empty_label, error->message);
    g_clear_error(&error);
    g_clear_pointer(&output, g_bytes_unref);
    g_object_unref(app);
    return;
  }
  if (app->shutting_down) {
    g_bytes_unref(output);
    g_object_unref(app);
    return;
  }

  GTask *task = g_task_new(app, NULL, history_parsed, NULL);
  g_task_set_task_data(task, output, (GDestroyNotify)g_bytes_unref);
  g_task_run_in_thread(task, parse_history_task);
  g_object_unref(task);
  g_object_unref(app);
}

static void load_history_async(ClipboardPicker *app) {
  if (app->history_loading)
    return;
  app->history_loading = TRUE;

  const gchar *argv[] = {"cliphist", "list", NULL};
  GError *error = NULL;
  GSubprocess *process =
      g_subprocess_newv(argv, G_SUBPROCESS_FLAGS_STDOUT_PIPE, &error);
  if (!process) {
    app->history_loading = FALSE;
    gtk_label_set_text(app->empty_label, error->message);
    g_clear_error(&error);
    return;
  }
  app->history_cancellable = g_cancellable_new();
  app->history_process = g_object_ref(process);
  g_subprocess_communicate_async(process, NULL, app->history_cancellable,
                                 history_loaded, g_object_ref(app));
}

static gchar *format_size(gsize size) {
  if (size < 1024)
    return g_strdup_printf("%zu B", size);
  if (size < 1024 * 1024)
    return g_strdup_printf("%.1f KiB", size / 1024.0);
  return g_strdup_printf("%.1f MiB", size / (1024.0 * 1024.0));
}

static void show_preview(ClipboardPicker *app, ClipboardItem *item,
                         GBytes *bytes) {
  g_set_object(&app->displayed_preview_item, item);
  gsize size = 0;
  const gchar *data = g_bytes_get_data(bytes, &size);
  gchar *size_text = format_size(size);
  gtk_label_set_text(app->size_value, size_text);
  g_free(size_text);

  GError *error = NULL;
  gchar *content_type = g_content_type_guess(NULL, (guchar *)data, size, NULL);
  gchar *mime = g_content_type_get_mime_type(content_type);
  gtk_label_set_text(app->mime_value, mime ? mime : content_type);
  g_free(mime);
  g_free(content_type);

  if (item->binary) {
    GdkTexture *texture = gdk_texture_new_from_bytes(bytes, &error);
    if (texture) {
      gtk_picture_set_paintable(app->picture, GDK_PAINTABLE(texture));
      gchar *details =
          g_strdup_printf("%d × %d pixels", gdk_texture_get_width(texture),
                          gdk_texture_get_height(texture));
      gtk_label_set_text(app->details_value, details);
      g_free(details);
      gtk_stack_set_visible_child_name(app->preview_stack, "image");
      g_object_unref(texture);
      g_bytes_unref(bytes);
      return;
    }
  }

  gchar *text = g_strndup(data, size);
  gsize characters = g_utf8_strlen(text, -1);
  gsize lines = *text ? 1 : 0;
  for (gchar *p = text; *p; p++)
    if (*p == '\n')
      lines++;
  gchar *details =
      g_strdup_printf("%zu characters · %zu lines", characters, lines);
  gtk_label_set_text(app->details_value, details);
  g_free(details);
  gtk_label_set_text(app->text_preview, text);
  gtk_stack_set_visible_child_name(app->preview_stack, "text");
  g_clear_error(&error);
  g_free(text);
  g_bytes_unref(bytes);
}

typedef struct {
  ClipboardPicker *app;
  ClipboardItem *item;
  GBytes *input;
  guint generation;
  GCancellable *cancellable;
} PreviewRequest;

static void preview_request_free(PreviewRequest *request) {
  g_clear_pointer(&request->input, g_bytes_unref);
  g_clear_object(&request->item);
  g_clear_object(&request->cancellable);
  g_clear_object(&request->app);
  g_free(request);
}

static void preview_loaded(GObject *source, GAsyncResult *result,
                           gpointer user_data) {
  PreviewRequest *request = user_data;
  ClipboardPicker *app = request->app;
  GSubprocess *process = G_SUBPROCESS(source);
  GBytes *bytes = NULL;
  GError *error = NULL;
  gboolean success =
      g_subprocess_communicate_finish(process, result, &bytes, NULL, &error);
  if (app->preview_process == process) {
    g_clear_object(&app->preview_process);
    g_clear_object(&app->preview_cancellable);
  }
  g_object_unref(process);

  if (success && bytes && !app->shutting_down)
    preview_cache_insert(app, request->item->raw, bytes);

  if (!app->shutting_down && request->generation == app->preview_generation) {
    if (success && bytes) {
      show_preview(app, request->item, bytes);
      bytes = NULL;
    } else {
      gtk_label_set_text(app->empty_label,
                         error ? error->message
                               : "Unable to decode clipboard entry");
      gtk_stack_set_visible_child_name(app->preview_stack, "empty");
    }
  }
  g_clear_error(&error);
  g_clear_pointer(&bytes, g_bytes_unref);
  preview_request_free(request);
}

static void load_preview_async(ClipboardPicker *app, ClipboardItem *item) {
  PreviewRequest *request = g_new0(PreviewRequest, 1);
  request->app = g_object_ref(app);
  request->item = g_object_ref(item);
  request->generation = app->preview_generation;
  request->input = g_bytes_new(item->raw, strlen(item->raw));
  request->cancellable = g_cancellable_new();
  app->preview_cancellable = g_object_ref(request->cancellable);

  const gchar *argv[] = {"cliphist", "decode", NULL};
  GError *error = NULL;
  GSubprocess *process = g_subprocess_newv(
      argv, G_SUBPROCESS_FLAGS_STDIN_PIPE | G_SUBPROCESS_FLAGS_STDOUT_PIPE,
      &error);
  if (!process) {
    gtk_label_set_text(app->empty_label, error->message);
    g_clear_error(&error);
    g_clear_object(&app->preview_cancellable);
    preview_request_free(request);
    return;
  }
  app->preview_process = g_object_ref(process);
  g_subprocess_communicate_async(process, request->input, request->cancellable,
                                 preview_loaded, request);
}

static void cancel_preview_load(ClipboardPicker *app) {
  g_clear_handle_id(&app->preview_timeout_id, g_source_remove);
  g_clear_object(&app->pending_preview_item);
  if (app->preview_cancellable) {
    g_cancellable_cancel(app->preview_cancellable);
    g_clear_object(&app->preview_cancellable);
  }
  if (app->preview_process) {
    g_subprocess_force_exit(app->preview_process);
    g_clear_object(&app->preview_process);
  }
}

static gboolean preview_debounce_elapsed(gpointer user_data) {
  ClipboardPicker *app = user_data;
  app->preview_timeout_id = 0;
  ClipboardItem *item = g_steal_pointer(&app->pending_preview_item);
  if (!app->shutting_down && item) {
    GBytes *cached = preview_cache_lookup(app, item->raw);
    if (cached)
      show_preview(app, item, cached);
    else
      load_preview_async(app, item);
  }
  g_clear_object(&item);
  return G_SOURCE_REMOVE;
}

static void schedule_preview(ClipboardPicker *app, ClipboardItem *item,
                             guint delay_ms) {
  if (item && item == app->displayed_preview_item)
    return;

  app->preview_generation++;
  cancel_preview_load(app);
  g_clear_object(&app->displayed_preview_item);

  if (!item) {
    guint count = app->search_items->len;
    const gchar *message = app->history_loading ? "Loading clipboard history…"
                           : count == 0         ? "Clipboard history is empty"
                           : app->pending_query[0]
                               ? "No matching clipboard entries"
                               : "Select an entry to preview";
    gtk_label_set_text(app->empty_label, message);
    gtk_stack_set_visible_child_name(app->preview_stack, "empty");
    return;
  }

  gtk_label_set_text(app->empty_label, "Loading preview…");
  gtk_stack_set_visible_child_name(app->preview_stack, "empty");
  app->pending_preview_item = g_object_ref(item);
  app->preview_timeout_id =
      g_timeout_add_full(G_PRIORITY_DEFAULT, delay_ms, preview_debounce_elapsed,
                         g_object_ref(app), g_object_unref);
}

static void selection_changed(GObject *object, GParamSpec *pspec,
                              gpointer user_data) {
  (void)pspec;
  ClipboardPicker *app = user_data;
  if (app->updating_results)
    return;

  ClipboardItem *item =
      gtk_single_selection_get_selected_item(GTK_SINGLE_SELECTION(object));
  schedule_preview(app, item, PREVIEW_DEBOUNCE_MS);
}

static void factory_setup(GtkSignalListItemFactory *factory, GtkListItem *item,
                          gpointer user_data) {
  (void)factory;
  (void)user_data;
  GtkLabel *label = GTK_LABEL(gtk_label_new(NULL));
  gtk_widget_add_css_class(GTK_WIDGET(label), "history-item");
  gtk_label_set_xalign(label, 0);
  gtk_label_set_ellipsize(label, PANGO_ELLIPSIZE_END);
  gtk_label_set_single_line_mode(label, TRUE);
  gtk_list_item_set_child(item, GTK_WIDGET(label));
}

static void factory_bind(GtkSignalListItemFactory *factory, GtkListItem *item,
                         gpointer user_data) {
  (void)factory;
  (void)user_data;
  ClipboardItem *value = gtk_list_item_get_item(item);
  GtkLabel *label = GTK_LABEL(gtk_list_item_get_child(item));
  gtk_label_set_text(label, value->display_single_line);
}

static gboolean is_resident(ClipboardPicker *app) {
  return (g_application_get_flags(G_APPLICATION(app)) &
          G_APPLICATION_IS_SERVICE) != 0;
}

static void dismiss_picker(ClipboardPicker *app) {
  if (is_resident(app) && app->window)
    gtk_widget_set_visible(GTK_WIDGET(app->window), FALSE);
  else
    g_application_quit(G_APPLICATION(app));
}

static gboolean on_window_close_requested(GtkWindow *window,
                                          gpointer user_data) {
  ClipboardPicker *app = user_data;
  if (!is_resident(app))
    return FALSE;
  gtk_widget_set_visible(GTK_WIDGET(window), FALSE);
  return TRUE;
}

static gboolean inject_paste(gpointer user_data) {
  ClipboardPicker *app = user_data;
  app->paste_timeout_id = 0;
  if (app->shutting_down)
    return G_SOURCE_REMOVE;

  const gchar *terminal_names[] = {
      "alacritty", "foot",    "kitty", "wezterm", "ghostty",
      "terminal",  "konsole", "xterm", "urxvt",   NULL};
  gboolean terminal = FALSE;
  for (const gchar **name = terminal_names; *name; name++)
    if (app->focused_app && g_strrstr(app->focused_app, *name))
      terminal = TRUE;

  const gchar *argv_emacs[] = {"wtype", "-M", "ctrl", "-P",   "y",
                               "-p",    "y",  "-m",   "ctrl", NULL};
  const gchar *argv_terminal[] = {"wtype", "-M", "ctrl", "-M", "shift",
                                  "-P",    "v",  "-p",   "v",  "-m",
                                  "shift", "-m", "ctrl", NULL};
  const gchar *argv_regular[] = {"wtype", "-M", "ctrl", "-P",   "v",
                                 "-p",    "v",  "-m",   "ctrl", NULL};
  const gchar *const *argv =
      app->focused_app && g_strrstr(app->focused_app, "emacs") ? argv_emacs
      : terminal                                               ? argv_terminal
                                                               : argv_regular;
  GError *error = NULL;
  if (!g_spawn_async(NULL, (gchar **)argv, NULL, G_SPAWN_SEARCH_PATH, NULL,
                     NULL, NULL, &error)) {
    g_warning("clipboard-picker: wtype failed: %s", error->message);
    g_clear_error(&error);
  }
  g_free(app->focused_app);
  app->focused_app = NULL;
  dismiss_picker(app);
  return G_SOURCE_REMOVE;
}

static void paste_finished(GObject *source, GAsyncResult *result,
                           gpointer user_data) {
  ClipboardPicker *app = user_data;
  GSubprocess *process = G_SUBPROCESS(source);
  GError *error = NULL;
  gboolean success =
      g_subprocess_communicate_finish(process, result, NULL, NULL, &error);
  if (app->paste_process == process) {
    g_clear_object(&app->paste_process);
    g_clear_object(&app->paste_cancellable);
  }
  g_object_unref(process);

  if (!success) {
    if (!app->shutting_down)
      g_warning("clipboard-picker: wl-copy failed: %s", error->message);
    g_clear_error(&error);
    g_object_unref(app);
    return;
  }

  if (!app->shutting_down) {
    GtkWindow *window = gtk_application_get_active_window(GTK_APPLICATION(app));
    if (window)
      gtk_widget_set_visible(GTK_WIDGET(window), FALSE);
    app->paste_timeout_id =
        g_timeout_add_full(G_PRIORITY_DEFAULT, 120, inject_paste,
                           g_object_ref(app), g_object_unref);
  }
  g_object_unref(app);
}

static void activate_item(GtkListView *view, guint position,
                          gpointer user_data) {
  (void)view;
  ClipboardPicker *app = user_data;
  ClipboardItem *item =
      g_list_model_get_item(G_LIST_MODEL(app->results), position);
  if (!item)
    return;
  GBytes *data = decode_item(item);
  if (!data) {
    g_object_unref(item);
    return;
  }

  if (app->paste_cancellable) {
    g_cancellable_cancel(app->paste_cancellable);
    g_clear_object(&app->paste_cancellable);
  }
  if (app->paste_process) {
    g_subprocess_force_exit(app->paste_process);
    g_clear_object(&app->paste_process);
  }

  const gchar *argv[] = {"wl-copy", NULL};
  GError *error = NULL;
  GSubprocess *process =
      g_subprocess_newv(argv, G_SUBPROCESS_FLAGS_STDIN_PIPE, &error);
  if (!process) {
    g_warning("clipboard-picker: unable to start wl-copy: %s", error->message);
    g_clear_error(&error);
    g_bytes_unref(data);
    g_object_unref(item);
    return;
  }
  app->paste_cancellable = g_cancellable_new();
  app->paste_process = g_object_ref(process);
  g_subprocess_communicate_async(process, data, app->paste_cancellable,
                                 paste_finished, g_object_ref(app));
  g_bytes_unref(data);
  g_object_unref(item);
}

static void on_search_activate(GtkSearchEntry *search, gpointer user_data) {
  (void)search;
  ClipboardPicker *app = user_data;
  guint position = gtk_single_selection_get_selected(app->selection);
  if (position != GTK_INVALID_LIST_POSITION)
    activate_item(app->list_view, position, app);
}

static void apply_search_results(ClipboardPicker *app, GPtrArray *matches) {
  ClipboardItem *selected =
      gtk_single_selection_get_selected_item(app->selection);
  if (selected)
    g_object_ref(selected);

  guint selected_position = GTK_INVALID_LIST_POSITION;
  if (selected) {
    for (guint i = 0; i < matches->len; i++) {
      if (g_ptr_array_index(matches, i) == selected) {
        selected_position = i;
        break;
      }
    }
  }

  app->updating_results = TRUE;
  guint count = g_list_model_get_n_items(G_LIST_MODEL(app->results));
  g_list_store_splice(app->results, 0, count, matches->pdata, matches->len);
  if (matches->len) {
    guint position =
        selected_position == GTK_INVALID_LIST_POSITION ? 0 : selected_position;
    gtk_single_selection_set_selected(app->selection, position);
  }
  app->updating_results = FALSE;

  ClipboardItem *current =
      gtk_single_selection_get_selected_item(app->selection);
  schedule_preview(app, current, SEARCH_PREVIEW_DEBOUNCE_MS);
  g_clear_object(&selected);
}

static void update_search_results(ClipboardPicker *app) {
  if (app->shutting_down)
    return;

  search_cache_prune(app, app->pending_query);
  GPtrArray *cached =
      g_hash_table_lookup(app->search_cache, app->pending_query);
  if (cached) {
    apply_search_results(app, cached);
    return;
  }

  GPtrArray *candidates = search_cache_find_candidates(app);
  GPtrArray *matches = g_ptr_array_new_with_free_func(g_object_unref);
  for (guint i = 0; i < candidates->len; i++) {
    ClipboardItem *item = g_ptr_array_index(candidates, i);
    if (g_strstr_len(item->search_text, -1, app->pending_query))
      g_ptr_array_add(matches, g_object_ref(item));
  }

  search_cache_insert(app, app->pending_query, matches);
  apply_search_results(app, matches);
  g_ptr_array_unref(matches);
}

static void on_search_changed(GtkEditable *editable, gpointer user_data) {
  ClipboardPicker *app = user_data;
  g_free(app->pending_query);
  app->pending_query = g_utf8_casefold(gtk_editable_get_text(editable), -1);
  app->preview_generation++;
  cancel_preview_load(app);
  update_search_results(app);
}

static gboolean on_key_pressed(GtkEventControllerKey *controller, guint keyval,
                               guint keycode, GdkModifierType state,
                               gpointer user_data) {
  (void)controller;
  (void)keycode;
  ClipboardPicker *app = user_data;
  if (keyval == GDK_KEY_Escape) {
    dismiss_picker(app);
    return GDK_EVENT_STOP;
  }

  gboolean ctrl = (state & GDK_CONTROL_MASK) != 0;
  if (ctrl && (keyval == GDK_KEY_n || keyval == GDK_KEY_p)) {
    guint count = g_list_model_get_n_items(G_LIST_MODEL(app->results));
    if (count == 0)
      return GDK_EVENT_STOP;
    guint current = gtk_single_selection_get_selected(app->selection);
    gint direction = keyval == GDK_KEY_n ? 1 : -1;
    gint target = current == GTK_INVALID_LIST_POSITION
                      ? (direction > 0 ? 0 : (gint)count - 1)
                      : (gint)current + direction;
    target = CLAMP(target, 0, (gint)count - 1);
    gtk_single_selection_set_selected(app->selection, target);
    gtk_list_view_scroll_to(app->list_view, target, GTK_LIST_SCROLL_FOCUS,
                            NULL);
    return GDK_EVENT_STOP;
  }
  return GDK_EVENT_PROPAGATE;
}

static gboolean finish_secondary_setup(gpointer user_data) {
  ClipboardPicker *app = user_data;
  app->secondary_setup_id = 0;
  if (app->shutting_down)
    return G_SOURCE_REMOVE;

  app->picture = GTK_PICTURE(gtk_picture_new());
  gtk_picture_set_content_fit(app->picture, GTK_CONTENT_FIT_CONTAIN);
  gtk_stack_add_named(app->preview_stack, GTK_WIDGET(app->picture), "image");

  GtkScrolledWindow *text_scroll =
      GTK_SCROLLED_WINDOW(gtk_scrolled_window_new());
  app->text_preview = GTK_LABEL(gtk_label_new(NULL));
  gtk_widget_add_css_class(GTK_WIDGET(app->text_preview), "text-preview");
  gtk_label_set_selectable(app->text_preview, TRUE);
  gtk_label_set_wrap(app->text_preview, TRUE);
  gtk_label_set_wrap_mode(app->text_preview, PANGO_WRAP_WORD_CHAR);
  gtk_label_set_xalign(app->text_preview, 0.0);
  gtk_label_set_yalign(app->text_preview, 0.0);
  gtk_widget_set_margin_top(GTK_WIDGET(app->text_preview), 16);
  gtk_widget_set_margin_bottom(GTK_WIDGET(app->text_preview), 16);
  gtk_widget_set_margin_start(GTK_WIDGET(app->text_preview), 16);
  gtk_widget_set_margin_end(GTK_WIDGET(app->text_preview), 16);
  gtk_scrolled_window_set_child(text_scroll, GTK_WIDGET(app->text_preview));
  gtk_stack_add_named(app->preview_stack, GTK_WIDGET(text_scroll), "text");

  GtkGrid *metadata = GTK_GRID(gtk_grid_new());
  gtk_widget_add_css_class(GTK_WIDGET(metadata), "metadata");
  gtk_grid_set_column_spacing(metadata, 16);
  gtk_grid_set_row_spacing(metadata, 6);
  const gchar *names[] = {"MIME", "Size", "Details"};
  GtkLabel **values[] = {&app->mime_value, &app->size_value,
                         &app->details_value};
  for (guint i = 0; i < 3; i++) {
    GtkLabel *key = GTK_LABEL(gtk_label_new(names[i]));
    gtk_label_set_xalign(key, 0.0);
    gtk_widget_add_css_class(GTK_WIDGET(key), "metadata-key");
    gtk_grid_attach(metadata, GTK_WIDGET(key), 0, i, 1, 1);
    *values[i] = GTK_LABEL(gtk_label_new(""));
    gtk_label_set_xalign(*values[i], 0.0);
    gtk_grid_attach(metadata, GTK_WIDGET(*values[i]), 1, i, 1, 1);
  }
  gtk_box_append(app->preview_box,
                 GTK_WIDGET(gtk_separator_new(GTK_ORIENTATION_HORIZONTAL)));
  gtk_box_append(app->preview_box, GTK_WIDGET(metadata));

  g_signal_connect(app->selection, "notify::selected-item",
                   G_CALLBACK(selection_changed), app);
  load_history_async(app);
  gtk_stack_set_visible_child_name(app->preview_stack, "empty");
  return G_SOURCE_REMOVE;
}

static void refresh_history(ClipboardPicker *app) {
  if (app->history_loading || !app->results)
    return;
  app->preview_generation++;
  cancel_preview_load(app);
  g_clear_object(&app->displayed_preview_item);
  app->updating_results = TRUE;
  g_list_store_remove_all(app->results);
  app->updating_results = FALSE;
  g_clear_pointer(&app->search_items, g_ptr_array_unref);
  app->search_items = g_ptr_array_new_with_free_func(g_object_unref);
  search_cache_reset(app);
  update_search_results(app);
  gtk_label_set_text(app->empty_label, "Loading clipboard history…");
  gtk_stack_set_visible_child_name(app->preview_stack, "empty");
  load_history_async(app);
}

static gboolean refresh_history_idle(gpointer user_data) {
  ClipboardPicker *app = user_data;
  app->history_refresh_id = 0;
  if (!app->shutting_down)
    refresh_history(app);
  return G_SOURCE_REMOVE;
}

static void clipboard_picker_activate(GApplication *application) {
  ClipboardPicker *app = (ClipboardPicker *)application;
  load_focused_app_async(app);
  if (app->window) {
    gtk_window_present(app->window);
    gtk_editable_set_text(GTK_EDITABLE(app->search), "");
    gtk_widget_grab_focus(GTK_WIDGET(app->search));
    if (!app->history_refresh_id && !app->secondary_setup_id) {
      app->history_refresh_id =
          g_idle_add_full(G_PRIORITY_DEFAULT_IDLE, refresh_history_idle,
                          g_object_ref(app), g_object_unref);
    }
    return;
  }

  GtkApplicationWindow *window = GTK_APPLICATION_WINDOW(
      gtk_application_window_new(GTK_APPLICATION(application)));
  app->window = GTK_WINDOW(window);
  gtk_window_set_title(app->window, "Clipboard History (C)");
  gtk_window_set_decorated(app->window, FALSE);
  g_signal_connect(app->window, "close-request",
                   G_CALLBACK(on_window_close_requested), app);
  gtk_widget_add_css_class(GTK_WIDGET(window), "clipboard-picker");
  gtk_window_set_default_size(GTK_WINDOW(window), 900, 520);

  GtkBox *root = GTK_BOX(gtk_box_new(GTK_ORIENTATION_VERTICAL, 12));
  gtk_widget_set_margin_top(GTK_WIDGET(root), 12);
  gtk_widget_set_margin_bottom(GTK_WIDGET(root), 12);
  gtk_widget_set_margin_start(GTK_WIDGET(root), 12);
  gtk_widget_set_margin_end(GTK_WIDGET(root), 12);
  gtk_window_set_child(GTK_WINDOW(window), GTK_WIDGET(root));

  app->search = GTK_SEARCH_ENTRY(gtk_search_entry_new());
  gtk_search_entry_set_placeholder_text(app->search,
                                        "Search clipboard history…");
  g_signal_connect(app->search, "changed", G_CALLBACK(on_search_changed), app);
  g_signal_connect(app->search, "activate", G_CALLBACK(on_search_activate),
                   app);
  gtk_box_append(root, GTK_WIDGET(app->search));

  GtkPaned *panes = GTK_PANED(gtk_paned_new(GTK_ORIENTATION_HORIZONTAL));
  gtk_widget_add_css_class(GTK_WIDGET(panes), "content-panes");
  gtk_paned_set_position(panes, 420);
  gtk_widget_set_vexpand(GTK_WIDGET(panes), TRUE);
  gtk_box_append(root, GTK_WIDGET(panes));

  GtkScrolledWindow *history = GTK_SCROLLED_WINDOW(gtk_scrolled_window_new());
  gtk_widget_add_css_class(GTK_WIDGET(history), "history");
  GtkListItemFactory *factory = gtk_signal_list_item_factory_new();
  g_signal_connect(factory, "setup", G_CALLBACK(factory_setup), app);
  g_signal_connect(factory, "bind", G_CALLBACK(factory_bind), app);

  app->results = g_list_store_new(clipboard_item_get_type());
  app->selection =
      gtk_single_selection_new(G_LIST_MODEL(g_object_ref(app->results)));
  GtkListView *list = GTK_LIST_VIEW(
      gtk_list_view_new(GTK_SELECTION_MODEL(app->selection), factory));
  app->list_view = list;
  g_signal_connect(list, "activate", G_CALLBACK(activate_item), app);
  gtk_scrolled_window_set_child(history, GTK_WIDGET(list));
  gtk_paned_set_start_child(panes, GTK_WIDGET(history));

  app->preview_box = GTK_BOX(gtk_box_new(GTK_ORIENTATION_VERTICAL, 0));
  gtk_widget_add_css_class(GTK_WIDGET(app->preview_box), "preview");
  app->preview_stack = GTK_STACK(gtk_stack_new());
  gtk_widget_set_hexpand(GTK_WIDGET(app->preview_stack), TRUE);
  gtk_widget_set_vexpand(GTK_WIDGET(app->preview_stack), TRUE);
  gtk_box_append(app->preview_box, GTK_WIDGET(app->preview_stack));
  app->empty_label = GTK_LABEL(gtk_label_new("Loading clipboard history…"));
  gtk_stack_add_named(app->preview_stack, GTK_WIDGET(app->empty_label),
                      "empty");
  gtk_paned_set_end_child(panes, GTK_WIDGET(app->preview_box));

  GtkCssProvider *css = gtk_css_provider_new();
  gtk_css_provider_load_from_string(
      css,
      "window.clipboard-picker { background-color: #0f0f0f; border-radius: "
      "10px; }\n"
      ".content-panes > separator { min-width: 12px; background: transparent; "
      "}\n"
      ".history, .preview { background-color: #1b1b1b; "
      "border: 1px solid rgba(255, 255, 255, 0.10); border-radius: 8px; }\n"
      ".preview stack, .preview scrolledwindow, .preview picture, "
      ".preview scrolledwindow viewport, .history scrolledwindow viewport { "
      "background-color: #1b1b1b; }\n"
      ".history-item { padding: 9px 10px; }\n"
      ".metadata { padding: 10px 12px; }\n"
      ".metadata-key { color: rgba(255, 255, 255, 0.55); }\n"
      ".text-preview { background-color: #0f0f0f; }");
  gtk_style_context_add_provider_for_display(
      gdk_display_get_default(), GTK_STYLE_PROVIDER(css),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_unref(css);

  GtkEventController *keys = gtk_event_controller_key_new();
  gtk_event_controller_set_propagation_phase(keys, GTK_PHASE_CAPTURE);
  g_signal_connect(keys, "key-pressed", G_CALLBACK(on_key_pressed), app);
  gtk_widget_add_controller(GTK_WIDGET(window), keys);

  gtk_window_present(GTK_WINDOW(window));
  gtk_widget_grab_focus(GTK_WIDGET(app->search));
  app->secondary_setup_id =
      g_timeout_add_full(G_PRIORITY_LOW, 16, finish_secondary_setup,
                         g_object_ref(app), g_object_unref);
}

static void clipboard_picker_init(ClipboardPicker *app) {
  app->pending_query = g_strdup("");
  app->search_items = g_ptr_array_new_with_free_func(g_object_unref);
  app->search_cache = g_hash_table_new_full(g_str_hash, g_str_equal, g_free,
                                            (GDestroyNotify)g_ptr_array_unref);
  search_cache_reset(app);
  app->preview_cache = g_hash_table_new(g_str_hash, g_str_equal);
  g_queue_init(&app->preview_cache_lru);
}

static void clipboard_picker_shutdown(GApplication *application) {
  ClipboardPicker *app = (ClipboardPicker *)application;
  app->shutting_down = TRUE;

  cancel_preview_load(app);
  g_clear_handle_id(&app->paste_timeout_id, g_source_remove);
  g_clear_handle_id(&app->secondary_setup_id, g_source_remove);
  g_clear_handle_id(&app->history_refresh_id, g_source_remove);
  if (app->focused_app_cancellable)
    g_cancellable_cancel(app->focused_app_cancellable);
  if (app->history_cancellable)
    g_cancellable_cancel(app->history_cancellable);
  if (app->history_process)
    g_subprocess_force_exit(app->history_process);
  if (app->paste_cancellable)
    g_cancellable_cancel(app->paste_cancellable);
  if (app->paste_process)
    g_subprocess_force_exit(app->paste_process);

  G_APPLICATION_CLASS(clipboard_picker_parent_class)->shutdown(application);
}

static void clipboard_picker_finalize(GObject *object) {
  ClipboardPicker *app = (ClipboardPicker *)object;
  g_free(app->focused_app);
  g_free(app->pending_query);
  g_clear_object(&app->pending_preview_item);
  g_clear_object(&app->displayed_preview_item);
  g_clear_object(&app->focused_app_cancellable);
  g_clear_object(&app->history_cancellable);
  g_clear_object(&app->history_process);
  g_clear_object(&app->preview_cancellable);
  g_clear_object(&app->preview_process);
  g_clear_object(&app->paste_cancellable);
  g_clear_object(&app->paste_process);
  g_clear_object(&app->results);
  g_clear_pointer(&app->search_items, g_ptr_array_unref);
  g_clear_pointer(&app->search_cache, g_hash_table_unref);
  preview_cache_clear(app);
  g_clear_pointer(&app->preview_cache, g_hash_table_unref);
  G_OBJECT_CLASS(clipboard_picker_parent_class)->finalize(object);
}

static void clipboard_picker_startup(GApplication *application) {
  G_APPLICATION_CLASS(clipboard_picker_parent_class)->startup(application);
  if ((g_application_get_flags(application) & G_APPLICATION_IS_SERVICE) != 0)
    g_application_hold(application);
}

static void clipboard_picker_class_init(ClipboardPickerClass *class) {
  GObjectClass *object_class = G_OBJECT_CLASS(class);
  object_class->finalize = clipboard_picker_finalize;
  GApplicationClass *application_class = G_APPLICATION_CLASS(class);
  application_class->startup = clipboard_picker_startup;
  application_class->activate = clipboard_picker_activate;
  application_class->shutdown = clipboard_picker_shutdown;
}

int main(int argc, char **argv) {
  /* Work around GTK partial-redraw artifacts across renderers:
   * https://gitlab.gnome.org/GNOME/gtk/-/work_items/8339 */
  g_setenv("GSK_DEBUG", "full-redraw", TRUE);
  ClipboardPicker *app =
      g_object_new(clipboard_picker_get_type(), "application-id", APP_ID,
                   "flags", G_APPLICATION_DEFAULT_FLAGS, NULL);
  int status = g_application_run(G_APPLICATION(app), argc, argv);
  g_object_unref(app);
  return status;
}
