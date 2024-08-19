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
        private Json.Object root_object;
        private Json.Array supported_emojis;
        public HashSet<string> added_combinations;
        private Gee.HashMap<string, EmojiData?> emoji_data_map;

        public EmojiDataManager () {
            supported_emojis = populate_supported_emojis_array ();
            emoji_data_map = new Gee.HashMap<string, EmojiData?> ();
            added_combinations = new HashSet<string> ();
        }

        private Json.Array populate_supported_emojis_array () {
            // Returns the known_supported_array by parsing metadata.json
            string file_contents;
            size_t length;

            try {
                var input_stream = GLib.resources_open_stream ("/io/github/halfmexican/Mingle/emoji_data/metadata.json", GLib.ResourceLookupFlags.NONE);
                var data_stream = new GLib.DataInputStream (input_stream);
                file_contents = data_stream.read_upto ("", -1, out length);

                Json.Parser parser = new Json.Parser ();
                parser.load_from_data (file_contents, -1);

                input_stream.close (null);
                data_stream.close (null);

                root_object = parser.get_root ().get_object ();

                // Navigate to known_supported_emoji
                Json.Array known_supported_array = root_object.get_array_member ("knownSupportedEmoji");
                return known_supported_array;
            } catch (Error e) {
                error ("Error: %s\n", e.message);
            }
        }

        public void add_emojis_to_flowbox (Gtk.FlowBox flowbox) {
            if (supported_emojis == null)
                supported_emojis = populate_supported_emojis_array ();

            ArrayForeach array_foreach_func = (array, index_, element_node) => {
                if (element_node.get_node_type () == Json.NodeType.VALUE) {
                    string emoji_code = element_node.get_string ();
                    add_emoji_to_flowbox (emoji_code, flowbox);
                }
            };
            supported_emojis.foreach_element (array_foreach_func);
        }

        public Json.Array get_supported_emojis () {
            return supported_emojis;
        }

        public void add_emoji_to_flowbox (string emoji_code, Gtk.FlowBox flowbox) {
            EmojiData? emoji_data = get_emoji_data (emoji_code);
            if (emoji_data != null) {
                var item = new EmojiLabel (emoji_data);
                flowbox.append (item);
                item.get_parent ().add_css_class ("card");
            }
        }

        public bool is_combination_added (string combination_key) {
            return added_combinations.contains (combination_key);
        }

        public void add_combination (string combination_key) {
            added_combinations.add (combination_key);
        }

        public void clear_added_combinations () {
            added_combinations.clear ();
        }

        public uint get_supported_emojis_length () {
            return this.supported_emojis.get_length ();
        }

        public Json.Array get_combinations_array_for_emoji (string emoji_code) {
            Json.Object data_object = root_object.get_object_member ("data");

            // Get the specific emoji data by code
            Json.Object emoji_object = data_object.get_object_member (emoji_code);
            if (emoji_object == null) {
                error ("Emoji code not found.");
            }

            // Get the combinations object
            Json.Object combinations_object = emoji_object.get_object_member ("combinations");
            if (combinations_object == null) {
                error ("Combinations not found.");
            }

            // Create a new array to hold all combinations before shuffling
            Json.Array unshuffled_combinations = new Json.Array ();

            // Iterate through all properties of the combinations object
            foreach (string key in combinations_object.get_members ()) {
                Json.Array combination_array = combinations_object.get_array_member (key);
                for (int i = 0; i < combination_array.get_length (); i++) {
                    unshuffled_combinations.add_element (combination_array.get_element (i));
                }
            }

            // Shuffle the unshuffled_combinations array
            Json.Array shuffled_combinations = new Json.Array ();
            GLib.Rand rng = new GLib.Rand ();
            while (unshuffled_combinations.get_length () > 0) {
                uint index = rng.int_range (0, (int32) unshuffled_combinations.get_length ());
                shuffled_combinations.add_element (unshuffled_combinations.get_element ((int) index));
                unshuffled_combinations.remove_element ((int) index);
            }

            return shuffled_combinations;
        }

        public Gee.List<Json.Object> get_combinations_for_emoji_lazy (string emoji_code, uint offset, int limit) {
            Json.Array all_combinations = get_combinations_array_for_emoji (emoji_code);
            Gee.List<Json.Object> batch = new Gee.ArrayList<Json.Object> ();

            // Ensure we do not go out of bounds
            uint end_index = offset + limit < all_combinations.get_length () ? offset + limit : all_combinations.get_length ();
            for (uint i = offset; i < end_index; i++) {
                batch.add (all_combinations.get_object_element (i));
            }

            return batch;
        }

        private Gee.HashMap<string, EmojiData?> create_emoji_data_map () {
            Gee.HashMap<string, EmojiData?> emoji_data_map = new Gee.HashMap<string, EmojiData?> ();
            Json.Object data_object = root_object.get_object_member ("data");
            foreach (string emoji_codepoint in data_object.get_members ()) {
                Json.Object emoji_object = data_object.get_object_member (emoji_codepoint);
                EmojiData emoji_data = EmojiData ();
                emoji_data.alt = emoji_object.get_string_member ("alt");
                emoji_data.keywords = emoji_object.get_array_member ("keywords");
                emoji_data.emoji_codepoint = emoji_codepoint;
                emoji_data.gboard_order = (int) emoji_object.get_int_member ("gBoardOrder");
                emoji_data.combinations = populate_combinations (emoji_object.get_object_member ("combinations"));
                emoji_data_map[emoji_codepoint] = emoji_data;
            }
            return emoji_data_map;
        }

        private Gee.HashMap<string, Gee.List<EmojiCombination?>> populate_combinations (Json.Object combinations_object) {
            var combinations_map = new Gee.HashMap<string, Gee.List<EmojiCombination?>> ();
            foreach (string other_emoji_codepoint in combinations_object.get_members ()) {
                Json.Array combinations_array = combinations_object.get_array_member (other_emoji_codepoint);
                var combinations_list = new Gee.ArrayList<EmojiCombination?> ();
                foreach (Json.Node combination_node in combinations_array.get_elements ()) {
                    Json.Object combination_object = combination_node.get_object ();
                    EmojiCombination combination = EmojiCombination () {
                        g_static_url = combination_object.get_string_member ("gStaticUrl"),
                        alt = combination_object.get_string_member ("alt"),
                        left_emoji = combination_object.get_string_member ("leftEmoji"),
                        left_emoji_codepoint = combination_object.get_string_member ("leftEmojiCodepoint"),
                        right_emoji = combination_object.get_string_member ("rightEmoji"),
                        right_emoji_codepoint = combination_object.get_string_member ("rightEmojiCodepoint"),
                        date = combination_object.get_string_member ("date"),
                        is_latest = combination_object.get_boolean_member ("isLatest"),
                        gboard_order = (int) combination_object.get_int_member ("gBoardOrder")
                    };
                    combinations_list.add (combination);
                }
                combinations_map[other_emoji_codepoint] = combinations_list;
            }
            return combinations_map;
        }

        public EmojiData ? get_emoji_data (string emoji_codepoint) {
            if (!emoji_data_map.has_key (emoji_codepoint)) {
                emoji_data_map[emoji_codepoint] = create_emoji_data (emoji_codepoint);
            }
            return emoji_data_map[emoji_codepoint];
        }

        private EmojiData ? create_emoji_data (string emoji_codepoint) {
            Json.Object data_object = root_object.get_object_member ("data");
            Json.Object? emoji_object = data_object.get_object_member (emoji_codepoint);

            if (emoji_object == null) {
                return null;
            }

            EmojiData emoji_data = EmojiData ();
            emoji_data.alt = emoji_object.get_string_member ("alt");
            emoji_data.keywords = emoji_object.get_array_member ("keywords");
            emoji_data.emoji_codepoint = emoji_codepoint;
            emoji_data.gboard_order = (int) emoji_object.get_int_member ("gBoardOrder");
            emoji_data.combinations = populate_combinations (emoji_object.get_object_member ("combinations"));

            return emoji_data;
        }

        public EmojiCombination ? get_combination (string left_emoji_codepoint, string right_emoji_codepoint) {
            var emoji_data = get_emoji_data (left_emoji_codepoint);
            if (emoji_data != null && emoji_data.combinations.has_key (right_emoji_codepoint)) {
                foreach (var combination in emoji_data.combinations[right_emoji_codepoint]) {
                    if (combination.is_latest) {
                        return combination;
                    }
                }
            }
            return null;
        }
    }
}