/* combined_emojji.vala
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

using Adw, Gtk, Gdk, Soup;
namespace Mingle {
    public class CombinedEmoji : Gtk.Button {
        private Texture _texture;
        private Texture _scaled_texture;
        private GLib.Settings settings = new GLib.Settings ("io.github.halfmexican.Mingle");
        private EmojiCombination combined_emoji;
        public Revealer revealer;
        public signal void copied ();

        public async CombinedEmoji (EmojiCombination combination_struct, Gtk.RevealerTransitionType transition, out bool image_loaded) {
            try {
                this.combined_emoji = combination_struct;
                this.tooltip_text = prettify_combined_alt_name (this.combined_emoji.alt);
                this.add_css_class ("flat");

                // Fetch the image asynchronously
                var input_stream = yield get_input_stream (combined_emoji.gstatic_url);
                var pixbuf = yield new Gdk.Pixbuf.from_stream_async (input_stream, null);

                // Textures
                _texture = Gdk.Texture.for_pixbuf (pixbuf);
                int width = pixbuf.get_width ();
                int height = pixbuf.get_height ();
                int scaled_width = width / 4;
                int scaled_height = height / 4;
                pixbuf = pixbuf.scale_simple (scaled_width, scaled_height, Gdk.InterpType.BILINEAR);
                _scaled_texture = Gdk.Texture.for_pixbuf (pixbuf);

                // Widgets
                var overlay = new Gtk.Overlay () {
                    child = new Gtk.Picture () {
                        width_request = 100,
                        height_request = 100,
                    },
                };

                revealer = new Gtk.Revealer () {
                    transition_duration = 800,
                    transition_type = transition,
                    reveal_child = false,
                };

                var picture = new Gtk.Picture () {
                    vexpand = false,
                    hexpand = true,
                    width_request = 100,
                    height_request = 100,
                    content_fit = Gtk.ContentFit.CONTAIN
                };

                this.set_child (overlay);
                picture.set_paintable (_texture);
                revealer.set_child (picture);
                overlay.add_overlay (revealer);
                image_loaded = true;
            } catch (GLib.Error error) {
                warning (error.message);
                image_loaded = false;
            }

            this.clicked.connect (() => {
                this.copy_image_to_clipboard ();
                message ("combined emoji: %s\n", combined_emoji.alt);
                this.copied ();
            });
        }

        public void reveal () {
            revealer.reveal_child = true;
        }

        private async InputStream ? get_input_stream (string url) throws Error {
            var session = new Soup.Session ();
            var message = new Soup.Message.from_uri ("GET", Uri.parse (url, NONE));
            InputStream input_stream;
            input_stream = yield session.send_async (message, Priority.HIGH, null);

            uint status_code = message.status_code;
            string reason = message.reason_phrase;

            if (status_code != 200) {
                warning ("Status Code: %x Reason: %s", status_code, reason);
            }

            return input_stream;
        }

        public void copy_image_to_clipboard () {
            var clipboard = Gdk.Display.get_default ().get_clipboard ();

            if (settings.get_boolean ("shrink-emoji")) {
                clipboard.set_texture (_scaled_texture);
            } else {
                clipboard.set_texture (_texture);
            }
        }

        public string prettify_combined_alt_name(string alt_name) {
            // Replace underscores with spaces and hyphens with ' + '
            string parsed_name = alt_name.replace("_", " ").replace("-", " + ");

            // Split into words
            var words = parsed_name.down().split(" ");
            string pretty_name = "";

            foreach (var word in words) {
                if (word.length > 0 && word != "+") { // Skip single '+'
                    pretty_name += word[0].to_string().up() + word.substring(1) + " ";
                } else if (word == "+") {
                    pretty_name += "+ "; // Add '+' with a space
                }
            }

            return pretty_name.strip(); // Remove any trailing space
        }
    }
}
