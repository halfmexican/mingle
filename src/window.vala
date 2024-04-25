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
    [GtkTemplate (ui = "/io/github/halfmexican/Mingle/gtk/window.ui")]
    public class Window : Adw.ApplicationWindow {
        // UI
        [GtkChild] private unowned Gtk.FlowBox left_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox right_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox combined_emojis_flow_box;
        [GtkChild] private unowned Gtk.ScrolledWindow combined_scrolled_window;
        [GtkChild] private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild] private unowned Gtk.PopoverMenu popover_menu;
        [GtkChild] private unowned Adw.ToolbarView toolbar;
        [GtkChild] private unowned Adw.Breakpoint breakpoint;
        private bool breakpoint_applied;
        private EmojiDataManager emoji_manager = new EmojiDataManager ();
        private GLib.Settings settings = new GLib.Settings ("io.github.halfmexican.Mingle");

        // Codepoints
        private string curr_left_emoji;
        private string curr_right_emoji;
        private string prev_left_emoji;
        private string prev_right_emoji;
        
        // Trasitions used for loading combined emojis
        private enum Transition {
           NONE,
           CROSSFADE,
           SLIDE,
           SWING,
           SWING_UP,
        }
        private Transition revealer_transition;

        // Lazy loading 
        private const int BATCH_SIZE = 20;
        private uint batch_offset = 0;
        public bool is_loading {get; set; default = false;}
        private delegate void EmojiActionDelegate (Mingle.EmojiLabel emoji_label);

        public Window (Mingle.Application app) {
            GLib.Object (application: app);
            this.settings.changed.connect (handle_pref_change);
            this.bind_property ("is-loading", left_emojis_flow_box, "sensitive", BindingFlags.INVERT_BOOLEAN);
            this.combined_scrolled_window.edge_overshot.connect (on_edge_overshot); // Handles loading more emojis on scroll
            setup_breakpoints ();
            apply_toolbar_style ();
            update_transition_type ();
            setup_style_switcher ();
            setup_emoji_flow_boxes ();
        }

        private void handle_pref_change (string key) {
            switch (key) {
                case "headerbar-style" :
                    apply_toolbar_style ();
                    break;
                case "transition-type":
                    update_transition_type ();
                    break;
            }
        }

        private void setup_emoji_flow_boxes () {
            connect_flow_box_signals (left_emojis_flow_box, handle_left_emoji_activation);
            connect_flow_box_signals (right_emojis_flow_box, handle_right_emoji_activation);
            emoji_manager.add_emojis_to_flowbox (left_emojis_flow_box);
            emoji_manager.add_emojis_to_flowbox (right_emojis_flow_box);
        }

        private void setup_breakpoints () {
            // Updates `breakpoint_applied` and our transition type
            breakpoint.apply.connect (() => {
                this.breakpoint_applied = true;
                update_transition_type ();
            });
            breakpoint.unapply.connect (() => {
                this.breakpoint_applied = false;
                update_transition_type ();
            });
        }

        private void setup_style_switcher () {
            Mingle.StyleSwitcher style_switcher = new Mingle.StyleSwitcher ();
            popover_menu.add_child (style_switcher, "style-switcher");
        }

        private void connect_flow_box_signals (Gtk.FlowBox flowbox, EmojiActionDelegate handler) {
            flowbox.child_activated.connect ((item) => {
                Mingle.EmojiLabel emoji_label = (Mingle.EmojiLabel) item.child;
                handler (emoji_label);
            });
        }

        private void handle_left_emoji_activation (Mingle.EmojiLabel emoji_label) {
            curr_left_emoji = emoji_label.get_code_point_str ();
            message (@"←Left Unicode: $curr_left_emoji, Emoji: $emoji_label");

            // Check for first-launch to determine if we show a little tip
            if (settings.get_boolean ("first-launch")) {
                create_and_show_toast ("Scroll down to load more emojis", 5);
                settings.set_boolean ("first-launch", false);
            }

            if (curr_left_emoji != prev_left_emoji && !is_loading) {
                // Clearing the existing emojis in the flow box only if a different left emoji is selected
                combined_emojis_flow_box.remove_all ();
                prev_left_emoji = curr_left_emoji;

                // Reset the offset for lazy loading
                batch_offset = 0;
                emoji_manager.clear_added_combinations ();
                populate_center_flow_box_lazy.begin ();

                if (curr_right_emoji != null) {
                    add_combined_emoji.begin (curr_left_emoji, curr_right_emoji, create_combined_emoji_revealer_transition (true));
                }
                right_emojis_flow_box.sensitive = true;
            }
            update_sensitivity_of_right_flowbox ();
        }

        private void handle_right_emoji_activation (Mingle.EmojiLabel emoji_label) {
            curr_right_emoji = emoji_label.get_code_point_str ();

            message (@"→Right Unicode: $curr_right_emoji, Emoji: $emoji_label\n");
            if (curr_right_emoji != prev_right_emoji) {
                prev_right_emoji = curr_right_emoji; // Update the last right emoji code
                add_combined_emoji.begin (curr_left_emoji, curr_right_emoji, create_combined_emoji_revealer_transition (false));
            }
        }

        private async void add_combined_emoji (string left_emoji_code, string right_emoji_code, Gtk.RevealerTransitionType transition) {
            var combined_emoji = yield emoji_manager.get_combined_emoji (left_emoji_code, right_emoji_code, transition);

            if (combined_emoji == null)
                return;

            combined_emojis_flow_box.prepend (combined_emoji);
            combined_emoji.revealer.reveal_child = true;
            combined_emoji.copied.connect (() => {
                create_and_show_toast ("Image copied to clipboard", 3);
            });
        }

        private async void populate_center_flow_box_lazy () {
            if (is_loading) {
                warning ("Already loading, aborting new call.\n");
                return; // Early return if already loading
            }
            is_loading = true;

            // Clear the flowbox if we're loading from the beginning
            if (batch_offset == 0) {
                combined_emojis_flow_box.remove_all ();
            }

            Gee.List<Json.Object> batch = emoji_manager.get_combinations_for_emoji_lazy (curr_left_emoji, batch_offset, BATCH_SIZE);
            if (batch.size <= 0) {
                message ("No more combinations to load.\n");
                create_and_show_toast ("No more combinations", 4);
                is_loading = false; // Reset the loading state
                return;
            } else if (batch_offset > 1) {
                create_and_show_toast("Loading More Combinations…", 2);
            }
            uint added_count = 0;
            foreach (Json.Object combination_object in batch) {
                string right_emoji_code = combination_object.get_member ("rightEmojiCodepoint").get_value ().get_string ();

                if (right_emoji_code == curr_left_emoji) {
                    right_emoji_code = combination_object.get_member ("leftEmojiCodepoint").get_value ().get_string ();
                }

                string combination_key = curr_left_emoji + "_" + right_emoji_code;

                if (!emoji_manager.is_combination_added (combination_key)) {
                    Mingle.CombinedEmoji combined_emoji = yield emoji_manager.get_combined_emoji (curr_left_emoji, right_emoji_code, create_combined_emoji_revealer_transition (true));

                    if (combined_emoji != null) {
                        combined_emoji.copied.connect (() => {
                            create_and_show_toast ("Image copied to clipboard", 3);
                        });

                        combined_emojis_flow_box.append (combined_emoji);
                        combined_emoji.revealer.reveal_child = true;

                        emoji_manager.add_combination (combination_key);
                        added_count++;
                    }
                }
            }
            batch_offset += added_count;
            is_loading = false;
        }

        [GtkCallback]
        public void select_random () {
            // Called when user clicks the "🎲" button
            // selects and activates a random emoji in the left flow box
            uint flowbox_length = emoji_manager.get_supported_emojis_length ();
            uint random_index = GLib.Random.int_range (0, (int32) flowbox_length);

            var child = left_emojis_flow_box.get_child_at_index ((int) random_index);
            left_emojis_flow_box.select_child (child);
            child.activate ();
        }

        private void create_and_show_toast (string message, int duration) {
            var toast = new Adw.Toast (message) {
                timeout = duration
            };
            toast_overlay.add_toast (toast);
        }

        // Toolbar Style
        private void apply_toolbar_style () {
            var style = get_toolbar_style ();
            toolbar.set_top_bar_style (style);
        }

        private Adw.ToolbarStyle get_toolbar_style () {
            uint style = settings.get_int ("headerbar-style");
            switch (style) {
                case 0:
                    return Adw.ToolbarStyle.FLAT;
                case 1:
                    return Adw.ToolbarStyle.RAISED;
                case 2:
                    return Adw.ToolbarStyle.RAISED_BORDER;
                default:
                    return Adw.ToolbarStyle.RAISED;
            }
        }

        // Combined Emoji Loading Transitions
        private void update_transition_type () {
            if (!breakpoint_applied) {
                this.revealer_transition = get_transition_type ();
            } else {
                 if (get_transition_type () == Transition.NONE) {
                    this.revealer_transition = Transition.NONE;
                } else if (get_transition_type () == Transition.CROSSFADE) {
                    this.revealer_transition = Transition.CROSSFADE;
                } else {
                    this.revealer_transition = Transition.SWING_UP;
                }
            }
        }

        private Transition get_transition_type () {
            uint transition = settings.get_int ("transition-type");
            switch (transition) {
                case 0: return Transition.NONE;
                case 1: return Transition.CROSSFADE;
                case 2: return Transition.SLIDE;
                case 3: return Transition.SWING;
                default: return Transition.NONE;
            }
        }

        private Gtk.RevealerTransitionType create_combined_emoji_revealer_transition (bool direction) {
            // Returns a RevealerTranstionType based on user settings
            // 0 is left, 1 is right
            switch (this.revealer_transition) {
                case Transition.NONE:
                    return Gtk.RevealerTransitionType.NONE;
                case Transition.CROSSFADE:
                    return Gtk.RevealerTransitionType.CROSSFADE;
                case Transition.SLIDE:
                    if (direction)
                        return Gtk.RevealerTransitionType.SLIDE_RIGHT;
                    return Gtk.RevealerTransitionType.SLIDE_LEFT;
                case Transition.SWING:
                    if (direction)
                        return Gtk.RevealerTransitionType.SWING_RIGHT;
                    return Gtk.RevealerTransitionType.SWING_LEFT;
                case Transition.SWING_UP:
                    return Gtk.RevealerTransitionType.SWING_UP;
                default :
                    return Gtk.RevealerTransitionType.CROSSFADE;
            }
        }

        // ChildFlowbox CSS
        private void set_child_sensitivity (Gtk.FlowBoxChild child) {
            Mingle.EmojiLabel emoji_label = (Mingle.EmojiLabel) child.get_child();
            string right_emoji_code = emoji_label.get_code_point_str();
            string combination_key = curr_left_emoji + "_" + right_emoji_code;
            child.set_sensitive (combination_key in emoji_manager);
        }

        private void update_sensitivity_of_right_flowbox () {
            Gtk.FlowBoxChild child = right_emojis_flow_box.get_child_at_index (0);
            int index = 0;

            while (child != null) {
                if (child is Gtk.Widget) {
                    set_child_sensitivity (child);

                    if (!child.get_sensitive ()) {
                        child.add_css_class ("invalid");
                    } else {
                        child.remove_css_class ("invalid");
                    }
                }
                index++;
                child = right_emojis_flow_box.get_child_at_index (index);
            }
        }

        private void on_edge_overshot (Gtk.PositionType pos_type) {
            // Loads more emojis when we scroll
            if (pos_type != Gtk.PositionType.BOTTOM) {
                return; // We are only interested in the bottom edge
            }

            if (!is_loading) {
                // Load the next batch of combined emojis
                populate_center_flow_box_lazy.begin ();
            }
        }
    }
}
