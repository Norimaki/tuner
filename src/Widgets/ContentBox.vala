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

public class Tuner.SourceContentBox : Object {


    Granite.Widgets.SourceList.Item item;
    public Tuner.ContentBox content_box;

    string label;
    string icon;
    Granite.Widgets.SourceList.ExpandableItem category;
    string name;
    string full_title;
    string? action_icon_name;
    string? action_tooltip_text;
    Gtk.Stack stack;
    Granite.Widgets.SourceList source_list;
    DirectoryController directory;

    public SourceContentBox(
        string label, 
        string icon,
        Granite.Widgets.SourceList.ExpandableItem category,
        string name,
        string full_title,
        string? action_icon_name,
        string? action_tooltip_text,
        Gtk.Stack stack,
        Granite.Widgets.SourceList source_list,
        DirectoryController directory
    ){
        this.label = label;
        this.icon = icon;
        this.category = category;
        this.name = name;
        this.full_title = full_title;
        this.action_icon_name = action_icon_name;
        this.action_tooltip_text = action_tooltip_text;
        this.stack = stack;
        this.source_list = source_list;
        this.directory = directory;

        item = new Granite.Widgets.SourceList.Item (label);
        item.icon = new ThemedIcon (action_icon_name);
        item.set_data<string> ("stack_child", name);
        item.set_data<string> ("content_type", "alt");
        item.set_data_full ("d",name, null);
        item.set_data_full ("dk",this, null);

        category.add (item);

        //content_box = new ContentBox(directory,null,full_title,null,action_icon_name,action_tooltip_text);

        //stack.add_named (content_box,name);

        item.action_activated.connect(()=>{
            Tuner.DebugNot.create("SourceContentBox","action_activated");
        });

        item.activated.connect(()=>{
            Tuner.DebugNot.create("SourceContentBox","activated");

        });

        item.notify.connect(()=>{
            Tuner.DebugNot.create("SourceContentBox","notify");

        });
    }

    construct{

        /*

        */


    }

    public void test(){
        content_box.show_alert ();
    }

    public void enable_count(){
        content_box.content_changed.connect (() => {
            uint count = 0;
            if (content_box.content != null) {
                count = content_box.content.item_count;
            }
            item.badge = @"$count";
        });
    }
}


public class Tuner.ContentBox : Gtk.Box {

    public signal void action_activated ();
    public signal void content_changed ();
    public signal void fresh ();
    public signal void h ();
    public signal void selected ();
    public signal void station_selected (Tuner.Model.Station_View station);

    private bool populated;

    public uint item_count {get; set;}


    private Gtk.Box header;
    private Gtk.Box _content;
    public AbstractContentList _content_list;
    public Gtk.Stack stack;
    public HeaderLabel header_label;
    public Gtk.Button shuffle_button;
    public string title;
    private Tuner.Model.Station_View _station;
       
    public Tuner.Model.Station_View station {
        get {
            return _station;
        }
        set {
            _station = value;
            station_selected(station);
        }
    }

    public StationSource? sourcedata;
    public   DirectoryController directory;

    private uint shuffle_button_source = 0;

    public void refresh(){

        if (sourcedata == null){
            show_nothing_found();
            return;
        }
        try {
            populated = true;

            var f = directory.stations_to_views(sourcedata.next ());

            if (f.size==0){
                show_nothing_found();
                return;
            }
            Tuner.DebugNot.create("s",f.size.to_string("%d"));

            var slist = new StationList.with_stations_views (f);
            slist.selection_changed.connect ((sv)=>{
                this.station=sv;
            });
            content = slist;
            item_count=slist.item_count;
            slist.bind_property ("item_count", this, "item_count", BindingFlags.DEFAULT);
        } catch (SourceError e) {
            populated = false;
            show_alert ();
        }
    }

    public ContentBox (DirectoryController directory, 
                       string name,
                       string? title,
                       string? action_icon_name,
                       string? action_tooltip_text) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 0,
            name:name
        );
        
        this.directory = directory;
        this.title = title;
        this.item_count = 0;

        this.selected.connect(()=>{
            Tuner.DebugNot.create("ContentBox",@"selected title $(title)");

            if (populated){

            }
            else{
            //stack.set_visible_child_full ("nothing-found", Gtk.StackTransitionType.NONE);
                refresh();
             }
        });
       



        this.action_activated.connect(()=>{

            try {
                var f = directory.stations_to_views(sourcedata.next ());
                var slist = new StationList.with_stations_views (f);
                slist.selection_changed.connect ((sv)=>{
                    this.station=sv;
                });
                content = slist;
            } catch (SourceError e) {
                show_alert ();
            }

        });



        stack = new Gtk.Stack ();

        var alert = new Granite.Widgets.AlertView (_("Nothing here"), _("Something went wrong loading radio stations data from radio-browser.info. Please try again later."), "dialog-warning");
        stack.add_named (alert, "alert");

        var no_results = new Granite.Widgets.AlertView (_("No stations found"), _("Please try a different search term."), "dialog-warning");
        stack.add_named (no_results, "nothing-found");

        header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        header.homogeneous = false;

        //if (icon != null) {
          //  header.pack_start (icon, false, false, 20);
       // }

        header_label = new HeaderLabel (title);
        header_label.xpad = 20;
        header_label.ypad = 20;
        header.pack_start (header_label, false, false);

        if (action_icon_name != null && action_tooltip_text != null) {
            shuffle_button = new Gtk.Button.from_icon_name (
                action_icon_name,
                Gtk.IconSize.LARGE_TOOLBAR
            );
            shuffle_button.valign = Gtk.Align.CENTER;
            shuffle_button.tooltip_text = action_tooltip_text;
            shuffle_button.clicked.connect (() => { 

                if (shuffle_button_source!=0){
                    Source.remove (shuffle_button_source);
                }
                else{
                    shuffle_button.set_sensitive (false);
                }
                shuffle_button_source = Timeout.add (256, () => {
                    action_activated ();
                    return false;
                });
            });
            header.pack_start (shuffle_button, false, false);            
        }

        pack_start (header, false, false);

        //if (subtitle != null) {
          //  var subtitle_label = new Gtk.Label (subtitle);
            //pack_start (subtitle_label);    
        //}

        pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false);

        _content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        _content.get_style_context ().add_class ("color-light");
        _content.valign = Gtk.Align.START;
        _content.get_style_context().add_class("welcome");

        var scroller = new Gtk.ScrolledWindow (null, null);
        //scroller.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

        scroller.add (_content);
        scroller.propagate_natural_height = true;
        //scroller.propagate_natural_height = false;

        stack.add_named (scroller, "content");
        add (stack);
        
        content_changed.connect (() => {

            //Tuner.DebugNot.create("contentbox","content_changed");
          

            scroller.unset_placement();
            scroller.set_hadjustment(null);
            scroller.set_vadjustment(null);
           });


    }

    public void show_alert () {

        //Tuner.DebugNot.create("show_alert",@" $(title)");

        stack.set_visible_child_full ("alert", Gtk.StackTransitionType.NONE);
        if (shuffle_button != null) shuffle_button.set_sensitive (true);
        shuffle_button_source = 0;
    }

    public void show_nothing_found () {
        content = new StationList();
        stack.set_visible_child_full ("nothing-found", Gtk.StackTransitionType.NONE);
        if (shuffle_button != null) shuffle_button.set_sensitive (true);
        shuffle_button_source = 0;
    }
    
    public AbstractContentList content { 
        set {

            //Tuner.DebugNot.create("contentbox",@"setting content $(title)");

            var childs = _content.get_children ();
            foreach (var c in childs) {
                c.destroy ();
            }
            _content_list = value;
            _content_list.title = this.title;

            //Tuner.DebugNot.create("contentbox",@"set_visible_child_full $(title)");

             stack.set_visible_child_full ("content", Gtk.StackTransitionType.NONE);

         

            _content.add (_content_list);
            _content.show_all ();
             content_changed ();
            if (shuffle_button != null) shuffle_button.set_sensitive (true);
            shuffle_button_source = 0;
            //set_no_show_all (false);

        }

        get {
            return _content_list;
        }
    }

   
    construct {
        get_style_context ().add_class ("color-dark");
    }

}


public class Tuner.ContentBox__ : Gtk.Box {

    public signal void action_activated ();
    public signal void content_changed ();
    public signal void fresh ();
    public signal void h ();

    private Gtk.Box header;
    private Gtk.Box _content;
    public AbstractContentList _content_list;
    public Gtk.Stack stack;
    public HeaderLabel header_label;
    public Gtk.Button shuffle_button;
    public string title;
    public string title2;

    private uint shuffle_button_source = 0;
    



    public ContentBox__ (Gtk.Image? icon,
                       string title,
                       string? subtitle,
                       string? action_icon_name,
                       string? action_tooltip_text) {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 0
        );

        this.title = title;
        this.title2 = "SASasfdsFsdfdsF";

        stack = new Gtk.Stack ();

        var alert = new Granite.Widgets.AlertView (_("Nothing here"), _("Something went wrong loading radio stations data from radio-browser.info. Please try again later."), "dialog-warning");

        stack.add_named (alert, "alert");

        var no_results = new Granite.Widgets.AlertView (_("No stations found"), _("Please try a different search term."), "dialog-warning");
        stack.add_named (no_results, "nothing-found");

        header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        header.homogeneous = false;

        if (icon != null) {
            header.pack_start (icon, false, false, 20);
        }

        header_label = new HeaderLabel (title);
        header_label.xpad = 20;
        header_label.ypad = 20;
        header.pack_start (header_label, false, false);

        if (action_icon_name != null && action_tooltip_text != null) {
            shuffle_button = new Gtk.Button.from_icon_name (
                action_icon_name,
                Gtk.IconSize.LARGE_TOOLBAR
            );
            shuffle_button.valign = Gtk.Align.CENTER;
            shuffle_button.tooltip_text = action_tooltip_text;
            shuffle_button.clicked.connect (() => { 

                if (shuffle_button_source!=0){
                    Source.remove (shuffle_button_source);
                }
                else{
                    shuffle_button.set_sensitive (false);
                }
                shuffle_button_source = Timeout.add (256, () => {
                    action_activated ();
                    return false;
                });
            });
            header.pack_start (shuffle_button, false, false);            
        }

        pack_start (header, false, false);

        if (subtitle != null) {
            var subtitle_label = new Gtk.Label (subtitle);
            pack_start (subtitle_label);    
        }

        pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false);

        _content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        _content.get_style_context ().add_class ("color-light");
        _content.valign = Gtk.Align.START;
        _content.get_style_context().add_class("welcome");

        var scroller = new Gtk.ScrolledWindow (null, null);
        //scroller.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

        scroller.add (_content);
        scroller.propagate_natural_height = true;
        //scroller.propagate_natural_height = false;

        stack.add_named (scroller, "content");
        add (stack);
        
        content_changed.connect (() => {

            //Tuner.DebugNot.create("contentbox","content_changed");
           

            scroller.unset_placement();
            scroller.set_hadjustment(null);
            scroller.set_vadjustment(null);
           });


    }

    public void show_alert () {

        //Tuner.DebugNot.create("show_alert",@" $(title)");

        stack.set_visible_child_full ("alert", Gtk.StackTransitionType.NONE);
        if (shuffle_button != null) shuffle_button.set_sensitive (true);
        shuffle_button_source = 0;
    }

    public void show_nothing_found () {
        content = new StationList();
        stack.set_visible_child_full ("nothing-found", Gtk.StackTransitionType.NONE);
        if (shuffle_button != null) shuffle_button.set_sensitive (true);
        shuffle_button_source = 0;
    }
    
    public AbstractContentList content { 
        set {

            //Tuner.DebugNot.create("contentbox",@"setting content $(title)");

            var childs = _content.get_children ();
            foreach (var c in childs) {
                c.destroy ();
            }
            _content_list = value;
            _content_list.title = this.title;

            //Tuner.DebugNot.create("contentbox",@"set_visible_child_full $(title)");

             stack.set_visible_child_full ("content", Gtk.StackTransitionType.NONE);

         

            _content.add (_content_list);
            _content.show_all ();
             content_changed ();
            if (shuffle_button != null) shuffle_button.set_sensitive (true);
            shuffle_button_source = 0;
            //set_no_show_all (false);

        }

        get {
            return _content_list;
        }
    }

   
    construct {
        get_style_context ().add_class ("color-dark");
    }

}
