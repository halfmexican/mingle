/* window.vala
 *
 * Copyright 2023-2025 José Hunter
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
        [GtkChild] private unowned Gtk.Stack window_stack;
        [GtkChild] private unowned Gtk.FlowBox left_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox right_emojis_flow_box;
        [GtkChild] private unowned Gtk.FlowBox combined_emojis_flow_box;
        [GtkChild] private unowned Gtk.ScrolledWindow combined_scrolled_window;
        [GtkChild] private unowned Gtk.ScrolledWindow left_scrolled_window;
        [GtkChild] private unowned Gtk.ScrolledWindow right_scrolled_window;
        [GtkChild] private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild] private unowned Gtk.PopoverMenu popover_menu;
        [GtkChild] private unowned Adw.ToolbarView toolbar_view;
        [GtkChild] private unowned Gtk.Button randomize_button;
        [GtkChild] private unowned Gtk.ToggleButton search_button;
        [GtkChild] private unowned Adw.Breakpoint breakpoint;
        [GtkChild] private unowned Gtk.SearchBar search_bar;
        [GtkChild] private unowned Gtk.SearchEntry search_entry;
        private GLib.Binding? scroll_binding;

        // Class variables
        private GLib.Settings settings = new GLib.Settings ("io.github.halfmexican.Mingle");
        private Mingle.StyleSwitcher style_switcher = new Mingle.StyleSwitcher ();
        private EmojiDataManager emoji_manager;
        private EmojiLabel left_emoji;
        private EmojiLabel right_emoji;

        // Codepoints
        private string prev_left_emoji;
        private string prev_right_emoji;

        // Transitions used for loading combined emojis
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
        private bool breakpoint_applied;
        public bool is_loading { get; private set; default = false; }
        private delegate void EmojiActionDelegate (Mingle.EmojiLabel emoji_label);

        // Constructor
        public Window (Mingle.Application app) {
            // Init
            GLib.Object (application : app); // base constructor
            popover_menu.add_child (style_switcher, "style-switcher"); // Add style switcher to popover menu
            setup_breakpoints ();
            update_transition_type ();
            bind_scroll_adjustments ();

            // Signals
            this.settings.changed.connect (handle_pref_change);
            this.bind_property ("is-loading", left_emojis_flow_box, "sensitive", BindingFlags.INVERT_BOOLEAN);
            this.combined_scrolled_window.edge_overshot.connect (on_edge_overshot); // Handles loading more emojis on scroll
            left_emojis_flow_box.set_filter_func (filter_emojis);
            search_entry.search_changed.connect (() => {
                left_emojis_flow_box.invalidate_filter ();
            });

            search_bar.notify["search-mode-enabled"].connect (() => {
                search_button.active = search_bar.search_mode_enabled;
                if (!search_bar.search_mode_enabled) {
                    bind_scroll_adjustments ();
                } else {
                    unbind_scroll_adjustments ();
                    toggle_search ();
                }
            });

            // Start thread to setup Emoji Manager once the window has been displayed
            this.show.connect (() => {
                start_setup_thread ();
            });
        }

        private async void setup_emoji_manager () {
            emoji_manager = yield new EmojiDataManager ();
            setup_emoji_flow_boxes ();
            apply_toolbar_view_style ();
        }

        private void start_setup_thread () {
            if (!Thread.supported ()) {
                warning ("Threads are not supported!\n");
                setup_emoji_manager.begin();
                return;
            }
            try {
                message ("Starting setup_emoji_manager thread\n");
                Thread<void> thread = new Thread<void>.try ("setup_emoji_manager_thread", () => {
                    setup_emoji_manager.begin ();
                    Idle.add (() => {
                        window_stack.set_visible_child (toast_overlay); // Switch to ToolbarView (Which is wrapped by toast overlay)
                        return false; // Remove the idle source
                    });
                });
            } catch (Error e) {
                error ("Error: %s\n", e.message);
            }

        }

        private void bind_scroll_adjustments () {
            Gtk.Adjustment left_adjustment = left_scrolled_window.get_vadjustment ();
            Gtk.Adjustment right_adjustment = right_scrolled_window.get_vadjustment ();
            scroll_binding = left_adjustment.bind_property (
                                                            "value",
                                                            right_adjustment,
                                                            "value",
                                                            BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE
            );
        }

        private void unbind_scroll_adjustments () {
            if (scroll_binding != null) {
                scroll_binding.unbind ();
                scroll_binding = null;
            }
        }

        private void handle_pref_change (string key) {
            switch (key) {
            case "headerbar-style":
                apply_toolbar_view_style ();
                break;
            case "transition-type":
                update_transition_type ();
                break;
            }
        }

        private bool filter_emojis (Gtk.FlowBoxChild child) {
            Mingle.EmojiLabel emoji_label = (Mingle.EmojiLabel) child.get_child ();
            string search_text = search_entry.text.up ();
            foreach (string keyword in emoji_label.keywords) {
                if (keyword.up ().contains (search_text)) {
                    return true;
                }
            }
            return false;
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

        private void connect_flow_box_signals (Gtk.FlowBox flowbox, EmojiActionDelegate handler) {
            flowbox.child_activated.connect ((item) => {
                Mingle.EmojiLabel emoji_label = (Mingle.EmojiLabel) item.child;
                handler (emoji_label);
            });
        }

        private void handle_left_emoji_activation (Mingle.EmojiLabel emoji_label) {
            left_emoji = emoji_label;
            string curr_left_emoji = left_emoji.codepoint;
            message (@"←Left Unicode: $curr_left_emoji, Emoji: $left_emoji");

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

                if (right_emoji != null) {
                    prepend_combined_emoji.begin (curr_left_emoji, right_emoji.codepoint, create_combined_emoji_revealer_transition (true));
                }
                right_emojis_flow_box.sensitive = true;
            }
            update_sensitivity_of_right_flowbox ();
            update_window_title ();
        }

        private void handle_right_emoji_activation (Mingle.EmojiLabel emoji_label) {
            right_emoji = emoji_label;
            string curr_right_emoji = right_emoji.codepoint;

            message (@"→Right Unicode: $curr_right_emoji, Emoji: $right_emoji");
            if (curr_right_emoji != prev_right_emoji) {
                prev_right_emoji = curr_right_emoji; // Update the last right emoji code
                prepend_combined_emoji.begin (left_emoji.codepoint, curr_right_emoji, create_combined_emoji_revealer_transition (false));
            }
            update_window_title ();
        }

        private async void prepend_combined_emoji (string left_emoji_code, string right_emoji_code, Gtk.RevealerTransitionType transition) {
            string combination_key = left_emoji_code + right_emoji_code;

            bool load_success;
            EmojiCombination? new_emoji_combination = emoji_manager.get_combination (left_emoji_code, right_emoji_code);
            if (new_emoji_combination != null) {
                Mingle.CombinedEmoji combined_emoji = yield new Mingle.CombinedEmoji (new_emoji_combination, transition, out load_success);
                if (load_success) {
                    combined_emojis_flow_box.prepend (combined_emoji);
                    combined_emoji.reveal ();
                    combined_emoji.copied.connect (() => {
                        create_and_show_toast ("Image copied to clipboard", 2);
                    });
                    emoji_manager.add_combination (combination_key);
                } else {
                    warning ("Invalid Combination\n %s", new_emoji_combination.gstatic_url);
                    combined_emoji.destroy ();
                }
            } else {
                warning ("No valid URL for the combined emoji.\n");
            }
        }

        private async void append_combined_emoji (string left_emoji_code, string right_emoji_code, Gtk.RevealerTransitionType transition) {
            string combination_key = left_emoji_code + right_emoji_code;
            if (emoji_manager.is_combination_added (combination_key)) {
                return;
            }

            bool load_success;
            EmojiCombination? new_emoji_combination = emoji_manager.get_combination (left_emoji_code, right_emoji_code);
            if (new_emoji_combination != null) {
                Mingle.CombinedEmoji combined_emoji = yield new Mingle.CombinedEmoji (new_emoji_combination, transition, out load_success);
                if (load_success) {
                    combined_emojis_flow_box.append (combined_emoji);
                    combined_emoji.copied.connect (() => {
                        create_and_show_toast ("Image copied to clipboard", 2);
                    });
                    combined_emoji.reveal ();
                    emoji_manager.add_combination (combination_key);
                } else {
                    warning ("Invalid Combination\n %s", new_emoji_combination.gstatic_url);
                    combined_emoji.destroy ();
                }
            } else {
                warning ("No valid URL for the combined emoji\n");
            }
        }

        public async void populate_center_flow_box_lazy () {
            if (is_loading) {
                warning ("Already loading, aborting new call\n");
                return; // Early return if already loading
            }
            is_loading = true;

            // Clear the flowbox if we're loading from the beginning
            if (batch_offset == 0) {
                combined_emojis_flow_box.remove_all ();
            }

            // Fetch a batch of combinations lazily
            Gee.List<Json.Object> batch = emoji_manager.lazy_load_combination_batch (left_emoji.codepoint, batch_offset, BATCH_SIZE);

            if (batch.size <= 0) {
                message ("No more combinations to load\n");
                create_and_show_toast ("No more combinations", 4);
                is_loading = false; // Reset the loading state
                return;
            } else if (batch_offset > 0) {
                create_and_show_toast ("Loading More Combinations…", 2);
            }

            foreach (Json.Object combination_object in batch) {
                string right_emoji_codepoint = combination_object.get_string_member ("rightEmojiCodepoint");
                if (right_emoji_codepoint == left_emoji.codepoint) {
                    right_emoji_codepoint = combination_object.get_string_member ("leftEmojiCodepoint");
                }

                string combination_key = left_emoji.codepoint + "_" + right_emoji_codepoint;

                append_combined_emoji.begin (left_emoji.codepoint, right_emoji_codepoint, create_combined_emoji_revealer_transition (true));
                emoji_manager.add_combination (combination_key);
            }
            batch_offset += BATCH_SIZE;
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

        [GtkCallback]
        private void toggle_search () {
            // Check the state of the search button and update the search mode
            if (search_button.active) {
                search_bar.search_mode_enabled = true;
            } else {
                search_bar.search_mode_enabled = false;
            }
        }

        private void create_and_show_toast (string message, int duration) {
            var toast = new Adw.Toast (message) {
                timeout = duration
            };
            toast_overlay.add_toast (toast);
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
            case 0 : return Transition.NONE;
            case 1 : return Transition.CROSSFADE;
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
            default:
                return Gtk.RevealerTransitionType.CROSSFADE;
            }
        }

        private void set_child_sensitivity (Gtk.FlowBoxChild child) {
            Mingle.EmojiLabel emoji_label = (Mingle.EmojiLabel) child.get_child ();
            string right_emoji_code = emoji_label.codepoint;

            // Check if the combination exists in the left emoji's combinations
            bool combination_exists = left_emoji.combinations.has_key (right_emoji_code);
            child.set_sensitive (combination_exists);
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

        private void update_window_title () {
            string title = "Mingle: ";
            if (left_emoji != null && right_emoji != null) {
                title += @"$left_emoji + $right_emoji";
            } else if (left_emoji != null) {
                title += @"$left_emoji + ?";
            } else if (right_emoji != null) {
                title += @"? + $right_emoji";
            } else {
                title += "? + ?";
            }
            this.set_title (title);
        }

        // Toolbar Style
        private void apply_toolbar_view_style () {
            var style = get_toolbar_view_style ();
            toolbar_view.set_top_bar_style (style);
            randomize_button.visible = true;
            search_button.visible = true;
        }

        private Adw.ToolbarStyle get_toolbar_view_style () {
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
