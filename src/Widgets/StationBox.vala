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

    public Model.Station station { private get; construct; }
    private StationContextMenu menu { get; set; }
    public Model.Station_View sv { get; construct; }

    public StationBox (Model.Station_View station_view) {
        Object (
            description: make_description (station_view.instance.location),
            title: make_title (station_view.instance.title, station_view.instance.starred),
            tag: make_tag (station_view.instance.codec, station_view.instance.bitrate),
            station: station_view.instance,
            sv: station_view
        );
    }
     
    public void on_icon_changed(IconTask icon_task){
        GLib.Idle.add (() => {
            IconTask.make_icon (station.id, station.url, icon, false);
            return false;
        });
    }

    construct {
        this.destroy.connect (() => {
            sv.icon_task.finished.disconnect(on_icon_changed);
            sv.destroy();
        });
        
        icon = new Gtk.Image();

        if (sv.icon_task.finallized){
            sv.icon_task.finished.disconnect(on_icon_changed);
            IconTask.make_icon (station.id, station.url, icon, false);
        }
        else{
            sv.icon_task.finished.connect(on_icon_changed);
            IconTask.make_icon(station.id, station.favicon_url, icon);
        }

        get_style_context().add_class("station-button");

        this.station.notify["starred"].connect ( (sender, prop) => {
            this.title = make_title (this.station.title, this.station.starred);
        });

        event.connect ((e) => {
            if (e.type == Gdk.EventType.BUTTON_PRESS && e.button.button == 3) {
                if (menu == null) {
                    menu = new StationContextMenu (this.sv);
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


