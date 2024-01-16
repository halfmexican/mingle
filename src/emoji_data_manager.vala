using Json, Soup, Gee;

namespace Mingle {
    public class EmojiDataManager {
        private Json.Node root_node;
        private Json.Array supported_emojis;

        public EmojiDataManager() {
           supported_emojis = populate_supported_emojis_array();
        }

        private Json.Array populate_supported_emojis_array() {
            // Returns the known_supported_array
            string file_contents;
            size_t length;

            try {
                var input_stream = GLib.resources_open_stream("/com/github/halfmexican/Mingle/metadata.json", GLib.ResourceLookupFlags.NONE);
                var data_stream = new GLib.DataInputStream(input_stream);
                file_contents = data_stream.read_upto("", -1, out length);

                Json.Parser parser = new Json.Parser ();
                parser.load_from_data (file_contents, -1);

                input_stream.close(null);
                data_stream.close(null);

                root_node = parser.get_root();

                // Navigate to known_supported_emoji
                Json.Object root_object = root_node.get_object ();
                Json.Node known_supported_node = root_object.get_member("knownSupportedEmoji");
                Json.Array known_supported_array = known_supported_node.get_array();
                return known_supported_array;

            } catch (Error e) {
                stderr.printf("Error: %s\n", e.message);
                return new Json.Array();
            }
        }

        public Json.Array get_supported_emojis () {
            return supported_emojis;
        }

        public void add_emojis_to_flowbox(Gtk.FlowBox flowbox) {
            if(supported_emojis == null)
                supported_emojis = populate_supported_emojis_array();

            for (int i = 0; i < supported_emojis.get_length(); i++) {
                Json.Node emoji_node = supported_emojis.get_element(i);
                add_emoji_to_flowbox(emoji_node.get_string(), flowbox);
            }
        }

        public void add_emoji_to_flowbox(string emoji, Gtk.FlowBox flowbox) { // Helper Method for emojis
            var item = new Mingle.EmojiLabel (emoji) {};
            flowbox.append (item);
            item.get_parent ().add_css_class ("card");
        }

        public Json.Array get_combinations_by_emoji_code(string emoji_code) {
            Json.Node data_node = root_node.get_object().get_member("data");
            Json.Object data_object = data_node.get_object();

            // Get the specific emoji data by code
             Json.Node emoji_node = data_object.get_member(emoji_code);
             if (emoji_node == null || emoji_node.get_node_type() != Json.NodeType.OBJECT) {
                stderr.printf("Emoji code not found or data is not an object.");
            }

            Json.Object emoji_object = emoji_node.get_object();

            // Get the combinations array
            Json.Node combinations_node = emoji_object.get_member("combinations");
            if (combinations_node == null || combinations_node.get_node_type() != Json.NodeType.ARRAY) {
                stderr.printf("Combinations not found or not an array.");
            }

            return combinations_node.get_array();
        }
    }
}
