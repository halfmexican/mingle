/* combined_emojji.vala
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

using Adw, Gtk, Soup;
namespace Mingle {
    public class CombinedEmoji : Gtk.Button {
        private Gdk.Texture _texture;
        public Gtk.Revealer revealer;
        public signal void copied ();
        private GLib.Settings settings = new GLib.Settings ("io.github.halfmexican.Mingle");

        public async CombinedEmoji (string gstatic_url, Gtk.RevealerTransitionType transition, out bool image_loaded) {
            try {
                this.add_css_class ("flat");
                // Fetch the image asynchronously
                var input_stream = yield get_input_stream (gstatic_url);
                var pixbuf = yield new Gdk.Pixbuf.from_stream_async (input_stream, null);

                bool shrink_emoji = settings.get_boolean ("shrink-emoji");

                if (shrink_emoji) {
                    int width = pixbuf.get_width ();
                    int height = pixbuf.get_height ();
                    int scaled_width = width / 4;
                    int scaled_height = height / 4;
                    pixbuf = pixbuf.scale_simple (scaled_width, scaled_height, Gdk.InterpType.BILINEAR);
                }

                _texture = Gdk.Texture.for_pixbuf (pixbuf);

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
                stderr.printf (error.message);
                image_loaded = false;
            }

            this.clicked.connect (() => {
                this.copy_image_to_clipboard (this._texture);
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
                warning ("Status Code: %x\n Reason: %s", status_code, reason);
            }

            return input_stream;
        }

        public void copy_image_to_clipboard (Gdk.Texture texture) {
            var clipboard = Gdk.Display.get_default ().get_clipboard ();
            clipboard.set_texture (texture);
        }
    }
}
