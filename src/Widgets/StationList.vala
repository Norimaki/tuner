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

using Gee;

public class Tuner.StationList : AbstractContentList {

    private static Tuner.StationList current_mapped;

    public signal void selection_changed (Model.Station_View sv);
    public signal void station_count_changed (uint count);
    public Model.Station_View selected_station;
    //private GLib.Queue<StationBox> boxes_list;
    private GenericArray<IconTask> icon_tasks;

    public Tuner.Window win;

    public ArrayList<Model.Station_View> stations_views {
        set construct {
            clear ();
            if (value == null) return;

            //boxes_list = new GLib.Queue<StationBox> ();
            icon_tasks = new GenericArray<IconTask> ();
            //Tuner.DebugNot.create("stationlist","loading boxes");
            foreach (var sv in value) {
                //sv.get_instance ();
                var box = new StationBox (sv);
                box.set_size_request (200, -1);
                box.set_hexpand(false);

               // var  hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
               // hbox.set_size_request (200, -1);
               // hbox.set_hexpand(false);
                //hbox.pack_start(box, false, false);

                box.clicked.connect (() => {
                    selection_changed (box.sv);
                    selected_station = box.sv;
                });
                //boxes_list.push_head(box);
                icon_tasks.add (sv.icon_task);
                add (box);
            }
            item_count = value.size;
            
            /* 
            GLib.Idle.add (() => {
                StationBox box = null;
                while ((box = boxes_list.pop_head ()) != null) {
                        //IconTaskLoader.add(box.sv.icon_task);
                }

                return false;
            });
            */
            //Tuner.DebugNot.create("stationlist","adding boxes");
            IconTaskLoader.bulk_add(icon_tasks);
        }
    }





    void update_target_cols_handler (int target_cols) {
        min_children_per_line = target_cols-1;
        max_children_per_line = target_cols;
    }

    public StationList () {
        int target_cols = Tuner.Winman.instance.target_cols;
       // Tuner.DebugNot.create("StationList",@"create $(target_cols.to_string ("%d"))");
        Object (
            homogeneous: true,
            min_children_per_line: target_cols-1,
            max_children_per_line: target_cols,
            column_spacing: 5,
            row_spacing: 5,
            border_width: 20,
            valign: Gtk.Align.START,
            selection_mode: Gtk.SelectionMode.NONE
        );
        set_size_request(200,-1);
        Tuner.Winman.instance.target_cols_up.connect_after (update_target_cols_handler);
        if (current_mapped == null || current_mapped!=this){
            current_mapped = this;
        }

        this.map.connect (()=>{
        int min;
        int nat;
        get_preferred_width(out min, out nat);
        //Tuner.DebugNot.create("get_preferred_width on map",@"$(min.to_string ("%d")) $(nat.to_string ("%d"))");
        });

    }

    public StationList.with_stations_views (Gee.ArrayList<Model.Station_View> stations) {
        this ();
        this.stations_views = stations;
    }

    public void clear () {
        var childs = get_children();
        foreach (var c in childs) {
            c.destroy();
        }
    }

    public override uint item_count { get; set; }


}