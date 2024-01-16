/* window.vala
 *
 * Copyright 2023 José Hunter
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
    [GtkTemplate (ui = "/com/github/halfmexican/Mingle/window.ui")]
    public class Window : Adw.ApplicationWindow {
        [GtkChild] private unowned Gtk.FlowBox left_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox right_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox combined_emojis_flow_box;
        [GtkChild] private unowned Adw.ToastOverlay toast_overlay;

        private EmojiDataManager emoji_manager = new EmojiDataManager();
        private Gee.HashMap<string, Json.Node> combinations_map;
        private Json.Array curr_emoji_combinations;
        HashSet<string> added_combinations = new HashSet<string>();
        string curr_left_emoji;
        string curr_right_emoji;

        private delegate void EmojiActionDelegate(Mingle.EmojiLabel emoji_label);

        public Window (Gtk.Application app) {
            GLib.Object (application: app);
            setup_emoji_flow_boxes();
            initialize_hashmap();
            right_emojis_flow_box.sensitive = false;
        }

        private void initialize_hashmap() {
            // MutiThreaded Hashmap implementation
            if (!Thread.supported()) {
                stderr.printf("Threads are not supported!\n");
            }

            try {
                Thread<Gee.HashMap<string, Json.Node>> thread = new Thread<Gee.HashMap<string, Json.Node>>.try (
                        "combinations_map_thread", () => {
                        return populate_combinations_map();
                    });
                combinations_map = thread.join();
            } catch (Error e) {
                stderr.printf("Error: %s\n", e.message);
            }
        }

        private void setup_emoji_flow_boxes() {
            connect_flow_box_signals(left_emojis_flow_box, handle_left_emoji_activation);
            connect_flow_box_signals(right_emojis_flow_box, handle_right_emoji_activation);

            emoji_manager.add_emojis_to_flowbox(left_emojis_flow_box);
            emoji_manager.add_emojis_to_flowbox(right_emojis_flow_box);
        }

        private void connect_flow_box_signals(Gtk.FlowBox flowBox, EmojiActionDelegate handler) {
            flowBox.child_activated.connect ((item) => {
                Mingle.EmojiLabel emoji_label = (Mingle.EmojiLabel) item.child;
                handler(emoji_label);
                combined_emojis_flow_box.remove_all();
            });
        }

        private void handle_left_emoji_activation(Mingle.EmojiLabel emoji_label) {
             // Clearing the existing emojis in the flow box
            combined_emojis_flow_box.remove_all();
            string emoji = emoji_label.emoji;
            curr_left_emoji = emoji_label.code_point_str;
            stdout.printf("Left Unicode: %s, Emoji: %s\n", curr_left_emoji, emoji);
            curr_emoji_combinations = emoji_manager.get_combinations_by_emoji_code(curr_left_emoji);
            if(curr_left_emoji != null && curr_right_emoji != null){
                this.get_emoji_combination.begin(curr_left_emoji, curr_right_emoji);
            }

            this.populate_center_flow_box.begin();
            right_emojis_flow_box.sensitive = true;
        }

        private void handle_right_emoji_activation(Mingle.EmojiLabel emoji_label) {
             // Clearing the existing emojis in the flow box
            combined_emojis_flow_box.remove_all();
            string emoji = emoji_label.emoji;
            curr_right_emoji = emoji_label.code_point_str;
            stdout.printf("Right Unicode: %s, Emoji: %s\n", curr_right_emoji, emoji);
            curr_emoji_combinations = emoji_manager.get_combinations_by_emoji_code(curr_left_emoji);
            this.get_emoji_combination.begin(curr_left_emoji, curr_right_emoji);
            this.populate_center_flow_box.begin();
        }

        private async void get_emoji_combination(string left_codepoint, string right_codepoint) {
            string combinationKey1 = left_codepoint + "_" + right_codepoint;
            string combinationKey2 = right_codepoint + "_" + left_codepoint;

            Json.Node combinationNode1 = combinations_map.get(combinationKey1);
            Json.Node combinationNode2 = combinations_map.get(combinationKey2);

            if (combinationNode1 != null) {
                yield process_combination(combinationNode1);
            } else if (combinationNode2 != null) {
                yield process_combination(combinationNode2);
            } else {
                stderr.printf("Combination not found for the provided codepoints.\n");
            }
        }

        private async void process_combination(Json.Node combinationNode) {
            // Extract the data from the combinationNode
            Json.Object combination_object = combinationNode.get_object();
            Json.Node gstatic_url_node = combination_object.get_member("gStaticUrl");
            Json.Node alt_node = combination_object.get_member("alt");
            string alt_name = alt_node.get_value().get_string();
            stdout.printf("\n%s\n",alt_name);

            if (gstatic_url_node != null && gstatic_url_node.get_node_type() == Json.NodeType.VALUE) {
                string gstatic_url = gstatic_url_node.get_value().get_string();

                Mingle.CombinedEmoji combined_emoji = yield new Mingle.CombinedEmoji(gstatic_url, true);
                combined_emojis_flow_box.insert(combined_emoji, 0);
                combined_emoji.revealer.reveal_child = true;
                combined_emoji.copied.connect(() => {
                    create_and_show_toast("Image copied to clipboard");
                });
            } else {
                stderr.printf("gStaticUrl is missing or not a value.\n");
            }
        }

        private Gee.HashMap<string, Json.Node> populate_combinations_map() {
            stdout.printf("populate_combinations_map thread started\n");
            Json.Array emoji_data = emoji_manager.get_supported_emojis();
            Gee.HashMap<string, Json.Node> combinations_map = new Gee.HashMap<string, Json.Node>();

            for (int i = 0; i < emoji_data.get_length(); i++) {
                Json.Node emoji_node = emoji_data.get_element(i);
                string emoji_code = emoji_node.get_string();
                Json.Array combinations = emoji_manager.get_combinations_by_emoji_code(emoji_code);

                for (int j = 0; j < combinations.get_length(); j++) {
                    Json.Node combination_node = combinations.get_element(j);
                    Json.Object combination_object = combination_node.get_object();

                    string leftEmojiCode = combination_object.get_member("leftEmojiCodepoint").get_value().get_string();
                    string rightEmojiCode = combination_object.get_member("rightEmojiCodepoint").get_value().get_string();

                    string combinationKey = leftEmojiCode + "_" + rightEmojiCode;
                    combinations_map.set(combinationKey, combination_node);
                }
            }
            stdout.printf("populate_combinations_map thread finishes\n");
            return combinations_map;
        }

        private void create_and_show_toast(string message) {
            var toast = new Adw.Toast(message) {timeout = 3};
            toast_overlay.add_toast(toast);
        }

        private async void populate_center_flow_box() {
            if (curr_left_emoji == null || curr_left_emoji == "") {
                stderr.printf("Left emoji is not selected.\n");
                return;
            }

            //if (known_supported_emojis == null)
                //known_supported_emojis = get_emoji_data();

            added_combinations =  new HashSet<string>();
            foreach (Json.Node emoji_node in emoji_manager.get_supported_emojis().get_elements()) {
                string rightEmojiCode = emoji_node.get_string();
                string combinationKey = curr_left_emoji + "_" + rightEmojiCode;

                Json.Node combinationNode = combinations_map.get(combinationKey);
                if (combinationNode == null || combinationNode.get_node_type() != Json.NodeType.OBJECT) {
                    continue; // Skip if combination not found
                }

                Json.Object combination_object = combinationNode.get_object();
                string gstatic_url = combination_object.get_member("gStaticUrl").get_value().get_string();
                string alt_name = combination_object.get_member("alt").get_value().get_string();

                // Asynchronously create and append the emoji
                Mingle.CombinedEmoji combined_emoji = yield new Mingle.CombinedEmoji(gstatic_url, false);

                // Check if combination already added
                if (!added_combinations.add(combinationKey)) {
                    continue;
                }

                combined_emoji.copied.connect(() => {
                    create_and_show_toast("Image copied to clipboard");
                });

                combined_emojis_flow_box.append(combined_emoji);
                combined_emoji.revealer.reveal_child = true;
            }
        }
    }
}



