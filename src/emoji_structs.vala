using Gtk, Mingle;

namespace Mingle {

    public struct EmojiData {
        public string alt;
        public Json.Array keywords;
        public string emoji_codepoint;
        public int gboard_order;
        public Gee.HashMap<string, Gee.List<EmojiCombination?>> combinations;
    }

    public struct EmojiCombination {
        public string g_static_url;
        public string alt;
        public string left_emoji;
        public string left_emoji_codepoint;
        public string right_emoji;
        public string right_emoji_codepoint;
        public string date;
        public bool is_latest;
        public int gboard_order;
    }
}