// Loaded in <head>, so that the theme is set before the page is drawn. The cookie reaches the web
// app on app.easydict.jiri.one and wins, because a choice made there changes nothing else.
// "theme" in localStorage is the key of the Django admin, which sees the choices of this page;
// the original colours are its "auto" (the admin then follows the system).
(function () {
    var themes = ["auto", "light", "dark"];
    var root = document.documentElement;
    var cookie = /(?:^|; )theme=(\w+)/.exec(document.cookie);
    var stored = cookie && cookie[1];
    try {
        stored = stored || localStorage.getItem("theme");
    } catch (error) {
        // storage blocked: the original colours
    }
    root.dataset.theme = themes.indexOf(stored) >= 0 ? stored : "auto";

    function remember(theme) {
        document.cookie = "theme=" + theme + "; Domain=easydict.jiri.one; Path=/; Max-Age=31536000; SameSite=Lax; Secure";
        try {
            localStorage.setItem("theme", theme);
        } catch (error) {
            // the theme still changes for this page
        }
    }
    // a choice from before the cookie, for the web app
    if (stored && !cookie) remember(stored);

    document.addEventListener("DOMContentLoaded", function () {
        document.querySelectorAll(".theme-toggle").forEach(function (button) {
            button.addEventListener("click", function () {
                var theme = themes[(themes.indexOf(root.dataset.theme) + 1) % themes.length];
                root.dataset.theme = theme;
                remember(theme);
            });
        });
    });
})();
