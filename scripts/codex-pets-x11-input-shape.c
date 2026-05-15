/*
 * 2026-05-15, 苍朮：设置 Codex pet 浮窗的 X11 输入命中区域。
 * 用途：调用 XShapeCombineRectangles，仅裁剪 ShapeInput，不改变窗口可见外观。
 * 参数：window-id padding 后接一组或多组 x y width height。
 * 返回值：0 表示设置成功；非 0 表示参数、X11 或 Shape 扩展错误。
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <X11/Xlib.h>
#include <X11/extensions/shape.h>

/*
 * 2026-05-15, 苍朮：把字符串解析为 long，并校验完整消费。
 * 用途：避免 shell 传入脏参数时误设置错误窗口或错误矩形。
 * 参数说明：value 为待解析字符串，name 为报错字段名。
 * 返回值：解析后的 long。
 */
static long parse_long_arg(const char *value, const char *name) {
  char *end = NULL;
  long parsed = strtol(value, &end, 0);
  if (end == value || end == NULL || *end != '\0') {
    fprintf(stderr, "Invalid %s: %s\n", name, value);
    exit(2);
  }
  return parsed;
}

/*
 * 2026-05-15, 苍朮：程序入口，给指定 X11 窗口设置一个或多个输入区域。
 * 用途：将 Electron 透明 overlay 的可点击范围缩到宠物本体，必要时附加通知托盘。
 * 参数说明：argv[1] window id；argv[2] padding；argv[3..] 为 x y width height 的重复组。
 * 返回值：0 表示成功；非 0 表示失败。
 */
int main(int argc, char **argv) {
  if (argc < 7 || ((argc - 3) % 4) != 0) {
    fprintf(stderr, "Usage: %s <window-id> <padding> <x> <y> <width> <height> [<x> <y> <width> <height>...]\n", argv[0]);
    return 2;
  }

  Window window = (Window)parse_long_arg(argv[1], "window-id");
  long padding = parse_long_arg(argv[2], "padding");
  int rect_count = (argc - 3) / 4;

  if (padding < 0) {
    fprintf(stderr, "Invalid padding.\n");
    return 2;
  }

  Display *display = XOpenDisplay(NULL);
  if (display == NULL) {
    fprintf(stderr, "Unable to open X display.\n");
    return 3;
  }

  int event_base = 0;
  int error_base = 0;
  if (!XShapeQueryExtension(display, &event_base, &error_base)) {
    fprintf(stderr, "X Shape extension is not available.\n");
    XCloseDisplay(display);
    return 4;
  }

  XRectangle *rects = calloc((size_t)rect_count, sizeof(XRectangle));
  if (rects == NULL) {
    fprintf(stderr, "Unable to allocate rectangles.\n");
    XCloseDisplay(display);
    return 5;
  }

  int output_count = 0;
  for (int index = 0; index < rect_count; index++) {
    int offset = 3 + index * 4;
    long x = parse_long_arg(argv[offset], "x");
    long y = parse_long_arg(argv[offset + 1], "y");
    long width = parse_long_arg(argv[offset + 2], "width");
    long height = parse_long_arg(argv[offset + 3], "height");

    if (width <= 0 || height <= 0) {
      continue;
    }

    long shaped_x = x - padding;
    long shaped_y = y - padding;
    long shaped_width = width + padding * 2;
    long shaped_height = height + padding * 2;

    if (shaped_x < 0) {
      shaped_width += shaped_x;
      shaped_x = 0;
    }
    if (shaped_y < 0) {
      shaped_height += shaped_y;
      shaped_y = 0;
    }
    if (shaped_width <= 0 || shaped_height <= 0) {
      continue;
    }

    rects[output_count].x = (short)shaped_x;
    rects[output_count].y = (short)shaped_y;
    rects[output_count].width = (unsigned short)shaped_width;
    rects[output_count].height = (unsigned short)shaped_height;
    output_count++;
  }

  if (output_count == 0) {
    fprintf(stderr, "Computed input shape is empty.\n");
    free(rects);
    XCloseDisplay(display);
    return 2;
  }

  XShapeCombineRectangles(display, window, ShapeInput, 0, 0, rects, output_count, ShapeSet, Unsorted);
  XSync(display, False);
  free(rects);
  XCloseDisplay(display);
  return 0;
}
