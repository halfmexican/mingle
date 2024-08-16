/* emoji_label.vala
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

using Gtk;
namespace Mingle {
    public class EmojiLabel : Adw.Bin {
        private string emoji;
        public string codepoint { get; private set; }
        public string alt_name { get; private set; }
        public Json.Array ? keywords { get; private set; }
        public EmojiLabel (EmojiData emoji_data) {
            this.emoji = codepoint_str_to_emoji(emoji_data.emoji_codepoint);
            this.codepoint = emoji_data.emoji_codepoint;
            this.alt_name = prettify_alt_name(emoji_data.alt);
            this.keywords = emoji_data.keywords;
            
            var label = new Gtk.Label (this.emoji) {
                css_classes = { "emoji", "title-1" },
                vexpand = true,
                hexpand = true,
                width_request = 50,
                height_request = 50,
                tooltip_text = alt_name,
            };
            this.child = label;
        }
        

        private string codepoint_str_to_emoji (string codepoint_str) {
            string emoji = "";
            foreach (string part in codepoint_str.split ("-")) {
                int64 code = int64.parse ("0x" + part);
                unichar emoji_char = (unichar) code;
                emoji += @"$(emoji_char)";
            }
            return emoji;
        }

        public string to_string() {
            return this.emoji;
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

    }
}
