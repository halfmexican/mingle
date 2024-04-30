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
        private Gee.HashMap<string, Json.Object> combinations_map;
        public HashSet<string> added_combinations = new HashSet<string> ();

        public EmojiDataManager () {
            supported_emojis = populate_supported_emojis_array ();
            initialize_combinations_map ();
        }

        private void initialize_combinations_map () {
            // Starts a separate thread if possible to populate this.combinations_map
            if (!Thread.supported ()) {
                warning ("Threads are not supported!\n");
                combinations_map = populate_combinations_map ();
                return;
            }

            try {
                message ("populate_combinations_map thread started\n");
                Thread<Gee.HashMap<string, Json.Object>> thread = new Thread<Gee.HashMap<string, Json.Object>>.try ("combinations_map_thread", populate_combinations_map);

                combinations_map = thread.join ();
                message ("populate_combinations_map thread end\n");
            } catch (Error e) {
                error ("Error: %s\n", e.message);
            }
        }

        private Gee.HashMap<string, Json.Object> populate_combinations_map () {
            // Returns a Hashmap of all possible emoji combinations
            Json.Array emoji_data = get_supported_emojis ();
            Gee.HashMap<string, Json.Object> combinations_map = new Gee.HashMap<string, Json.Object> ();

            for (int i = 0; i < emoji_data.get_length (); i++) {
                string emoji_code = emoji_data.get_string_element (i);
                Json.Array combinations = get_combinations_array_for_emoji (emoji_code);

                for (int j = 0; j < combinations.get_length (); j++) {
                    Json.Object combination_object = combinations.get_object_element (j);
                    combination_object.ref();

                    string left_emoji_code = combination_object.get_string_member ("leftEmojiCodepoint");
                    string right_emoji_code = combination_object.get_string_member ("rightEmojiCodepoint");

                    string combination_key1 = left_emoji_code + "_" + right_emoji_code;
                    string combination_key2 = right_emoji_code + "_" + left_emoji_code;
                    combinations_map.set (combination_key1, combination_object);
                    combinations_map.set (combination_key2, combination_object);
                }
            }
            return combinations_map;
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
            // Adds all the emojis from this.supported_emojis to the flowbox
            if (supported_emojis == null)
                supported_emojis = populate_supported_emojis_array ();

            Json.Object data_object = root_object.get_object_member ("data");

            ArrayForeach array_foreach_func = (array, index_, element_node) => {
                if (element_node.get_node_type () == Json.NodeType.VALUE) {
                    string emoji_code = element_node.get_string ();
                    Json.Object emoji_object = data_object.get_object_member (emoji_code);

                    if (emoji_object != null) {
                        string alt_name = prettify_alt_name (emoji_object.get_string_member ("alt"));
                        Json.Array? keywords = emoji_object.get_array_member ("keywords");
                        add_emoji_to_flowbox (emoji_code, alt_name, keywords, flowbox);
                    }
                }
            };
            supported_emojis.foreach_element (array_foreach_func);
        }

        public Json.Array get_supported_emojis () {
            return supported_emojis;
        }

        public void add_emoji_to_flowbox (string emoji_code, string alt_name, Json.Array? keywords, Gtk.FlowBox flowbox) {
            var item = new Mingle.EmojiLabel (emoji_code, alt_name, keywords);
            flowbox.append (item);
            item.get_parent ().add_css_class ("card");
        }

        public string prettify_alt_name (string alt_name) {
            var words = alt_name.replace ("_", " ").down ().split (" ");
            string pretty_name = "";

            foreach (var word in words) {
                if (word.length > 0)
                    pretty_name += word[0].to_string ().up () + word.substring (1) + " ";
            }
            return pretty_name;
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

            // Get the combinations array
            Json.Array combinations_array = emoji_object.get_array_member ("combinations");
            if (combinations_array == null) {
                error ("Combinations not found.");
            }

            return combinations_array;
        }

        public bool contains (string combination_key) {
            // Returns true if the given combination is in our HashMap
            // leftEmoji_rightEmoji
            return combinations_map.has_key (combination_key);
        }

        public Gee.List<Json.Object> get_combinations_for_emoji (string leftEmojiCode) {
            Gee.List<Json.Object> relevant_combinations = new Gee.ArrayList<Json.Object> ();
            foreach (var key in combinations_map.keys) {
                if (key.contains (leftEmojiCode)) {
                    relevant_combinations.add (combinations_map.get (key));
                }
            }
            return relevant_combinations;
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

        public async Mingle.CombinedEmoji ? create_combined_emoji (string left_codepoint, string right_codepoint, Gtk.RevealerTransitionType transition) {
            // Asynchronously instantiate and return a CombinedEmoji given both left and right code_points
            string combination_key = left_codepoint + "_" + right_codepoint;

            Json.Object combination_object = combinations_map.get (combination_key);

            if (combination_object != null) {
                string gstatic_url = combination_object.get_string_member ("gStaticUrl");
                if (gstatic_url != null) {
                    Mingle.CombinedEmoji combined_emoji = yield new Mingle.CombinedEmoji (gstatic_url, transition);
                    return combined_emoji;
                } else {
                    error ("gStaticUrl is missing.\n");
                }
            } else {
                warning ("Combination not found for the provided codepoints.\n");
            }
            return null;
        }
    }
}
