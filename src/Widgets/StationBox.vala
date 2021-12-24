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

public class Tuner.StationBox : Tuner.WelcomeButton {

    public Model.Station station { get; construct; }
    public StationContextMenu menu { get; private set; }
    public IconTask icon_task { get; private set; }

    public StationBox (Model.Station station) {
        Object (
            description: make_description (station.location),
            title: make_title (station.title, station.starred),
            tag: make_tag (station.codec, station.bitrate),
            icon: new Gtk.Image(),
            station: station
        );
        this.icon_task = new IconTask (station.id, station.favicon_url,null);


        if (icon_task.finallized){
            icon_task.finished.disconnect(on_icon_changed);
            IconTask.make_icon (station.id, station.url, icon, false);
        }
        else{
            icon_task.finished.connect(on_icon_changed);
            IconTask.make_icon(station.id, station.favicon_url, icon);
        }
    }

    public void on_icon_changed(IconTask icon_task){
        GLib.Idle.add (() => {
            IconTask.make_icon (station.id, station.url, icon, false);
            return false;
        });
    }

    construct {

        this.destroy.connect (() => {
            this.icon_task.finished.disconnect(on_icon_changed);
        });

        get_style_context().add_class("station-button");

        this.station.notify["starred"].connect ( (sender, prop) => {
            this.title = make_title (this.station.title, this.station.starred);
        });


        // TODO Use a AsyncQueue with limited threads
        //new Thread<int>("station-box", realize_favicon);


        event.connect ((e) => {
            if (e.type == Gdk.EventType.BUTTON_PRESS && e.button.button == 3) {
                // Optimization:
                // Create menu on demand not on construction
                // because it is rarely used for all stations
                if (menu == null) {
                    menu = new StationContextMenu (this.station);
                    menu.attach_to_widget (this, null);
                    menu.show_all ();
                }

                menu.popup_at_pointer ();
                return true;
            }
            return false;
        });
        always_show_image = true;
    }

    private static string make_title (string title, bool starred) {
        if (!starred) return title;
        return Application.STAR_CHAR + title;
    }

    private static string make_tag (string codec, int bitrate) {
        var tag = codec;
        if (bitrate > 0)
        {
            tag = tag + " " + bitrate.to_string() + "k";
        }

        return tag;
    }

    private static string make_description (string location) {
        if (location.length > 0) 
            return _(location);
        else
            return location;
    }



}
