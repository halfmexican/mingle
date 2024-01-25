/* emoji_data_manager.vala
 *
 * Copyright 2023-2024 José Hunter
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using Json, Soup, Gee;

namespace Mingle {
    public class EmojiDataManager {
        private Json.Node root_node;
        private Json.Array supported_emojis;
        private Gee.HashMap<string, Json.Node> combinations_map;
        public HashSet<string> added_combinations = new HashSet<string>();

        public EmojiDataManager() {
            supported_emojis = populate_supported_emojis_array();
            initialize_combinations_map();
        }

        private void initialize_combinations_map() {
            if (!Thread.supported()) {
                stderr.printf("Threads are not supported!\n");
                combinations_map = populate_combinations_map();
                return;
            }

            try {
                Thread<Gee.HashMap<string, Json.Node>> thread = new Thread<Gee.HashMap<string, Json.Node>>.try (
                    "combinations_map_thread", populate_combinations_map);
                combinations_map = thread.join();
            } catch (Error e) {
                stderr.printf("Error: %s\n", e.message);
            }
        }

        private Json.Array populate_supported_emojis_array() {
            // Returns the known_supported_array
            string file_contents;
            size_t length;

            try {
                var input_stream = GLib.resources_open_stream("/com/github/halfmexican/Mingle/emoji_data/metadata.json", GLib.ResourceLookupFlags.NONE);
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

        public bool is_combination_added(string combinationKey) {
            return added_combinations.contains(combinationKey);
        }

        public void add_combination(string combinationKey) {
            added_combinations.add(combinationKey);
        }

        public void clear_added_combinations() {
            added_combinations.clear();
        }

        public Json.Array get_combinations_array_for_emoji(string emoji_code) {
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

        public Gee.List<Json.Node> get_combinations_for_emoji(string leftEmojiCode) {
            Gee.List<Json.Node> relevantCombinations = new Gee.ArrayList<Json.Node>();

            // Retrieve all combinations that include the EmojiCode, regardless of whether it is on the left or right
            foreach (var key in combinations_map.keys) {
                if (key.contains(leftEmojiCode)) {
                    relevantCombinations.add(combinations_map.get(key));
                }
            }

            return relevantCombinations;
        }

        public Gee.List<Json.Node> get_combinations_for_emoji_lazy(string emojiCode, uint offset, int limit) {
            Json.Array allCombinations = get_combinations_array_for_emoji(emojiCode);
            Gee.List<Json.Node> batch = new Gee.ArrayList<Json.Node>();

            // Ensure we do not go out of bounds
           uint endIndex = offset + limit < allCombinations.get_length() ? offset + limit : allCombinations.get_length();

            for (uint i = offset; i < endIndex; i++) {
                batch.add(allCombinations.get_element(i));
            }

            return batch;
        }


        private Gee.HashMap<string, Json.Node> populate_combinations_map() {
            stdout.printf("populate_combinations_map thread started\n");
            Json.Array emoji_data = get_supported_emojis();
            Gee.HashMap<string, Json.Node> combinations_map = new Gee.HashMap<string, Json.Node>();

            for (int i = 0; i < emoji_data.get_length(); i++) {
                Json.Node emoji_node = emoji_data.get_element(i);
                string emoji_code = emoji_node.get_string();
                Json.Array combinations = get_combinations_array_for_emoji(emoji_code);

                for (int j = 0; j < combinations.get_length(); j++) {
                    Json.Node combination_node = combinations.get_element(j);
                    Json.Object combination_object = combination_node.get_object();

                    string leftEmojiCode = combination_object.get_member("leftEmojiCodepoint").get_value().get_string();
                    string rightEmojiCode = combination_object.get_member("rightEmojiCodepoint").get_value().get_string();

                    string combinationKey1 = leftEmojiCode + "_" + rightEmojiCode;
                    string combinationKey2 = rightEmojiCode + "_" + leftEmojiCode;
                    combinations_map.set(combinationKey1, combination_node);
                    combinations_map.set(combinationKey2, combination_node);
                }
            }
            return combinations_map;
        }

         public async Mingle.CombinedEmoji get_combined_emoji(string left_codepoint, string right_codepoint) {
            string combinationKey = left_codepoint + "_" + right_codepoint; // The key is always left + right

            Json.Node combinationNode = combinations_map.get(combinationKey);

            if (combinationNode != null) {
                Json.Object combination_object = combinationNode.get_object();
                Json.Node gstatic_url_node = combination_object.get_member("gStaticUrl");

                if (gstatic_url_node != null && gstatic_url_node.get_node_type() == Json.NodeType.VALUE) {
                    string gstatic_url = gstatic_url_node.get_value().get_string();
                    Mingle.CombinedEmoji combined_emoji = yield new Mingle.CombinedEmoji(gstatic_url, true);
                    return combined_emoji;
                } else {
                    stderr.printf("gStaticUrl is missing or not a value.\n");
                }
            } else {
            stderr.printf("Combination not found for the provided codepoints.\n");
        }
            return null;
        }
    }
}
