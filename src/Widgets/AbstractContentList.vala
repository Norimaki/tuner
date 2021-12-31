/*
* Copyright (c) 2020-2021 Louis Brauer <louis@brauer.family>
*
* This file is part of Tuner.
*
* Tuner is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Tuner is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Tuner.  If not, see <http://www.gnu.org/licenses/>.
*
*/

public abstract class Tuner.AbstractContentList : Gtk.FlowBox {

    public abstract uint item_count { get; set; }

    public override void get_preferred_width (out int _minimum_width, out int _natural_width) {

        int minimum_width;
        int natural_width;
        base.get_preferred_width(out minimum_width, out natural_width);
        _minimum_width = 200;
        _natural_width = natural_width;
        if (_natural_width < _minimum_width){
            _natural_width = _minimum_width;
        }
    }
    
}