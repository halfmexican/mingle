/* window.vala
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
    [GtkTemplate (ui = "/com/github/halfmexican/Mingle/gtk/window.ui")]
    public class Window : Adw.ApplicationWindow {
        [GtkChild] private unowned Gtk.FlowBox left_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox right_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox combined_emojis_flow_box;
        [GtkChild] private unowned Gtk.ScrolledWindow combined_scrolled_window;
        [GtkChild] private unowned Adw.ToastOverlay toast_overlay;

        private GLib.Settings settings;
        private EmojiDataManager emoji_manager = new EmojiDataManager();
        private string curr_left_emoji;
        private string curr_right_emoji;
        private string prev_left_emoji;
        private string prev_right_emoji;

        // lazy loading properties
        private const int BATCH_SIZE = 20;
        private uint batch_offset = 0;
        private bool is_loading = false;

        private delegate void EmojiActionDelegate(Mingle.EmojiLabel emoji_label);

        public Window (Gtk.Application app, GLib.Settings settings) {
            GLib.Object (application: app);
            setup_emoji_flow_boxes();
            right_emojis_flow_box.sensitive = false;
            this.settings = settings;
            combined_scrolled_window.edge_overshot.connect(on_edge_overshot);
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
            });
        }

        private void handle_left_emoji_activation(Mingle.EmojiLabel emoji_label) {
            string emoji = emoji_label.emoji;
            curr_left_emoji = emoji_label.code_point_str;
            stdout.printf("Left Unicode: %s, Emoji: %s\n", curr_left_emoji, emoji);

            if (settings.get_boolean("first-launch")) {
                // It's the first launch, show the toast.
                create_and_show_toast("Scroll down to load more emojis");

                // Now set the key to false so that this doesn't appear again.
                settings.set_boolean("first-launch", false);
            }

            if (curr_left_emoji != prev_left_emoji) {
                // Clearing the existing emojis in the flow box only if a different left emoji is selected
                combined_emojis_flow_box.remove_all();
                prev_left_emoji = curr_left_emoji;

                // Reset the offset for lazy loading
                batch_offset = 0;
                emoji_manager.clear_added_combinations();
                this.populate_center_flow_box_lazy.begin();

                if (curr_right_emoji != null) {
                    add_combined_emoji.begin(curr_left_emoji, curr_right_emoji);
                }
                right_emojis_flow_box.sensitive = true;
            }
        }

        private void handle_right_emoji_activation(Mingle.EmojiLabel emoji_label) {
            string emoji = emoji_label.emoji;
            curr_right_emoji = emoji_label.code_point_str;

            stdout.printf("Right Unicode: %s, Emoji: %s\n", curr_left_emoji, emoji);
            if (curr_right_emoji != prev_right_emoji) {
                prev_right_emoji = curr_right_emoji; // Update the last right emoji code
                add_combined_emoji.begin(curr_left_emoji, curr_right_emoji);
            }
        }

        private void create_and_show_toast(string message) {
            var toast = new Adw.Toast(message) {timeout = 3};
            toast_overlay.add_toast(toast);
        }

        private async void add_combined_emoji (string leftEmojiCode, string RightEmojiCode) {
            var combined_emoji = yield emoji_manager.get_combined_emoji(leftEmojiCode, RightEmojiCode);

            if(combined_emoji == null){
                return;
            }

            combined_emojis_flow_box.prepend(combined_emoji);
            combined_emoji.revealer.reveal_child = true;
            combined_emoji.copied.connect(() => {
                create_and_show_toast("Image copied to clipboard");
            });
        }

        private async void populate_center_flow_box_lazy() {
            if (is_loading) {
                stderr.printf("Already loading, aborting new call.\n");
                return; // Early return if already loading
            }
            is_loading = true;

            if (curr_left_emoji == null || curr_left_emoji == "") {
                stderr.printf("Left emoji is not selected.\n");
                is_loading = false;
                return;
            }

            // Clear the flowbox if we're loading from the beginning
            if (batch_offset == 0) {
                combined_emojis_flow_box.remove_all();
            }

            Gee.List<Json.Node> batch = emoji_manager.get_combinations_for_emoji_lazy(curr_left_emoji, batch_offset, BATCH_SIZE);

            if (batch.size == 0) {
                stderr.printf("No more combinations to load.\n");
                is_loading = false; // Reset the loading state
                return;
            }

            uint added_count = 0;
            foreach (Json.Node combinationNode in batch) {
                Json.Object combination_object = combinationNode.get_object();
                string rightEmojiCode = combination_object.get_member("rightEmojiCodepoint").get_value().get_string();

                if (rightEmojiCode == curr_left_emoji) {
                   rightEmojiCode = combination_object.get_member("leftEmojiCodepoint").get_value().get_string();
                }

                string combinationKey = curr_left_emoji + "_" + rightEmojiCode;

                if (!emoji_manager.is_combination_added(combinationKey)) {
                    Mingle.CombinedEmoji combined_emoji = yield emoji_manager.get_combined_emoji(curr_left_emoji, rightEmojiCode);

                    if (combined_emoji != null) {
                        combined_emoji.copied.connect(() => {
                            create_and_show_toast("Image copied to clipboard");
                        });

                        combined_emojis_flow_box.append(combined_emoji);
                        combined_emoji.revealer.reveal_child = true;

                        emoji_manager.add_combination(combinationKey);
                        added_count++;

                    }
                }
            }
            batch_offset += added_count;
            is_loading = false;
        }

        private void on_edge_overshot(Gtk.PositionType pos_type) {
            if (pos_type != Gtk.PositionType.BOTTOM) {
                return; // We are only interested in the bottom edge
            }

            if (!is_loading) {
                // Load the next batch of combined emojis
                populate_center_flow_box_lazy.begin();
            }
        }
    }
}
