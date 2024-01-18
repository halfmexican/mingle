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
        string curr_left_emoji;
        string curr_right_emoji;

        private delegate void EmojiActionDelegate(Mingle.EmojiLabel emoji_label);

        public Window (Gtk.Application app) {
            GLib.Object (application: app);
            setup_emoji_flow_boxes();
            right_emojis_flow_box.sensitive = false;
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

            if(curr_left_emoji != null && curr_right_emoji != null){
                this.add_combined_emoji.begin(curr_left_emoji, curr_right_emoji);
            }
            this.populate_center_flow_box.begin(curr_left_emoji);
            right_emojis_flow_box.sensitive = true;
        }

        private void handle_right_emoji_activation(Mingle.EmojiLabel emoji_label) {
             // Clearing the existing emojis in the flow box
            combined_emojis_flow_box.remove_all();
            string emoji = emoji_label.emoji;
            curr_right_emoji = emoji_label.code_point_str;
            stdout.printf("Right Unicode: %s, Emoji: %s\n", curr_right_emoji, emoji);
            this.add_combined_emoji.begin(curr_left_emoji, curr_right_emoji);
            this.populate_center_flow_box.begin(curr_left_emoji);
        }

        private void create_and_show_toast(string message) {
            var toast = new Adw.Toast(message) {timeout = 3};
            toast_overlay.add_toast(toast);
        }

        private async void add_combined_emoji (string leftEmojiCode, string RightEmojiCode) {
            var combined_emoji = yield emoji_manager.get_combined_emoji(leftEmojiCode, RightEmojiCode);
            combined_emojis_flow_box.prepend(combined_emoji);
            combined_emoji.revealer.reveal_child = true;
            combined_emoji.copied.connect(() => {
                create_and_show_toast("Image copied to clipboard");
            });
        }

        private async void populate_center_flow_box(string leftEmojiCode) {
            if (leftEmojiCode == null || leftEmojiCode == "") {
                stderr.printf("Left emoji is not selected.\n");
                return;
            }

            var relevantCombinations = emoji_manager.get_combinations_for_emoji(leftEmojiCode);

            foreach (Json.Node combinationNode in relevantCombinations) {
                Json.Object combination_object = combinationNode.get_object();
                string rightEmojiCode = combination_object.get_member("rightEmojiCodepoint").get_value().get_string();

                if (rightEmojiCode == leftEmojiCode) {
                   rightEmojiCode = combination_object.get_member("leftEmojiCodepoint").get_value().get_string();
                }

                string combinationKey = leftEmojiCode + "_" + rightEmojiCode;

                if (!emoji_manager.is_combination_added(combinationKey)) {
                    //stdout.printf("Attempting to add combination: %s\n", combinationKey);
                    Mingle.CombinedEmoji combined_emoji = yield emoji_manager.get_combined_emoji(leftEmojiCode, rightEmojiCode);

                    if (combined_emoji != null) {
                        combined_emoji.copied.connect(() => {
                            create_and_show_toast("Image copied to clipboard");
                        });

                        combined_emojis_flow_box.append(combined_emoji);
                        combined_emoji.revealer.reveal_child = true;

                        emoji_manager.add_combination(combinationKey);
                    }
                }
            }
        }
    }
}
