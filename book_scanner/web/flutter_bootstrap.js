{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // 从本地加载 canvaskit，避免访问被墙的 gstatic.com
    canvasKitBaseUrl: "canvaskit/",
  },
});
