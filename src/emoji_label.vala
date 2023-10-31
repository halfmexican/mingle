/* emoji_label.vala
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
using Gtk;
namespace Mingle {
    public class EmojiLabel : Adw.Bin {
        public string code_point_str;
        public string emoji;

        public EmojiLabel(string code_point_str) {
            this.code_point_str = code_point_str;
            this.emoji = code_point_str_to_emoji(code_point_str);
            this.child = new Gtk.Label(this.emoji) {
                css_classes = { "emoji", "card", "title-1" },
                vexpand = true,
                hexpand = true,
                width_request = 50,
                height_request = 50,
            };
        }

         private string code_point_str_to_emoji(string code_point_str) {
            string emoji = "";
            foreach (string part in code_point_str.split("-")) {
                int64 code_point = int64.parse("0x" + part);
                unichar emoji_char = (unichar) code_point;
                emoji += @"$(emoji_char)";
            }
            return emoji;
        }
    }
}
