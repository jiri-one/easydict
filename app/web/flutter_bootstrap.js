{{flutter_js}}
{{flutter_build_config}}

// The phone frame only with a mouse: in a host element Flutter does not see the
// on-screen keyboard, which would then cover the results. Same query as index.html.
const framed = matchMedia(
  "(min-width: 760px) and (min-height: 600px) and (pointer: fine)",
).matches;
const config = {
  // otherwise the fonts come from Google Fonts (see tool/build_web.sh)
  fontFallbackBaseUrl: "fonts/",
};
if (framed) config.hostElement = document.getElementById("screen");

_flutter.loader.load({
  config,
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine(config);
    await appRunner.runApp();
    // in the phone the engine has emptied its host element itself
    if (!framed) document.getElementById("phone").remove();
  },
});
