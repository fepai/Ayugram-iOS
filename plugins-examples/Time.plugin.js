// ayu-plugin {"id":"com.ayugram.example.time","name":"Time","version":"1.0","author":"fepai","description":"Sample plugin: send .time in any chat to get the current time. Demonstrates commands, send hooks and settings."}

plugin.onload = function () {
    plugin.log("Time plugin loaded");
};

plugin.onunload = function () {
    plugin.log("Time plugin unloaded");
};

// A per-plugin settings screen rendered in AyuGram settings.
plugin.createSettings([
    { type: "switch", key: "twentyFour", title: "24-hour format" },
    { type: "selector", key: "format", title: "Style", options: ["short", "full"] },
    { type: "text", key: "prefix", title: "Prefix" }
]);

// Commands: sending ".time" in a chat cancels the message and replies instead.
plugin.addCommand(".time", function (args) {
    var now = new Date();
    var text;
    if (plugin.settings.get("twentyFour") === "1") {
        text = now.toLocaleTimeString(undefined, { hour12: false });
    } else {
        text = now.toLocaleTimeString();
    }
    if (plugin.settings.get("format") === "full") {
        text = now.toLocaleString();
    }
    var prefix = plugin.settings.get("prefix");
    if (prefix) {
        text = prefix + " " + text;
    }
    return text;
});

// A send-message hook: rewrites outgoing text. Return {strategy:"cancel"} to
// drop a message, a string to replace the text, or nothing to keep it.
plugin.addOnSendMessageHook(function (text) {
    if (text === ".ping") {
        return "pong";
    }
    return text;
});

// A context menu item on messages.
plugin.addMessageMenuItem("Show length", function (ctx) {
    plugin.log("message length: " + (ctx.text || "").length);
    plugin.reply("Length: " + (ctx.text || "").length + " chars");
});
