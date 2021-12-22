//https://github.com/elementary/music/blob/master/src/Widgets/SourceListView.vala
//https://github.com/elementary/music/blob/master/src/Views/Wrappers/ViewWrapper.vala

public class Tuner.GridView : Gtk.Grid {
    public ContentBox content {get; private set;}
    public GridView (ContentBox cb, Gtk.Stack s) {
        Object (
            name: cb.name
        );
        content=cb;
        add(content);
        s.add_named (this, this.name);
    }
}

public abstract class Tuner.ViewWrapper : Gtk.Grid {
    public enum Hint {
        NONE,
        SELECTION,
        FAVORITE_RESULTS,
        SEARCH_RESULTS,
        GENRE,
        PLAYLIST;
    }
}

public interface Tuner.SourceListEntry : Granite.Widgets.SourceList.Item {
}

public class Tuner.SourceListItem : Granite.Widgets.SourceList.Item, SourceListEntry, Granite.Widgets.SourceListDragDest {

    public GridView view { get; construct; }
    public ViewWrapper.Hint hint { get; construct; }
    public GLib.Icon? activatable_icon { get; construct; }

    private Gtk.Menu playlist_menu;
    public signal void playlist_rename_clicked (GridView view, SourceListItem item);
    public signal void playlist_edit_clicked (GridView view);
    public signal void playlist_remove_clicked (GridView view);
    public signal void playlist_media_added (GridView view, string[] media);

    public SourceListItem (GridView view, string name, ViewWrapper.Hint hint, GLib.Icon icon, GLib.Icon? activatable_icon = null) {
        Object (
            activatable_icon: activatable_icon,
            hint: hint,
            icon: icon,
            name: name,
            view: view
        );
        this.badge = "";


    }
    construct {
        playlist_menu = new Gtk.Menu ();
        switch (hint) {
            case ViewWrapper.Hint.NONE:
                break;
            case ViewWrapper.Hint.SELECTION:
                var playlist_rename = new Gtk.MenuItem.with_label (_("Rename"));
                var playlist_remove = new Gtk.MenuItem.with_label (_("Remove"));
                playlist_menu.append (playlist_rename);
                playlist_menu.append (playlist_remove);
                playlist_rename.activate.connect (() => {
                    playlist_rename_clicked (view, this);
                });
                playlist_remove.activate.connect (() => {
                    playlist_remove_clicked (view);
                });
                break;
            case ViewWrapper.Hint.FAVORITE_RESULTS:
                break;
            case ViewWrapper.Hint.SEARCH_RESULTS:
                break;
            case ViewWrapper.Hint.GENRE:
                break;
            case ViewWrapper.Hint.PLAYLIST:
                break;
            default:
                break;
        }
        playlist_menu.show_all ();
    }
    
    public override Gtk.Menu? get_context_menu () {
        if (playlist_menu != null) {
            if (playlist_menu.get_attach_widget () != null) {
                playlist_menu.detach ();
            }
            return playlist_menu;
        }
        return null;
    }

    private bool data_drop_possible (Gdk.DragContext context, Gtk.SelectionData data) {
        return hint == ViewWrapper.Hint.PLAYLIST
            && data.get_target () == Gdk.Atom.intern_static_string ("text/uri-list");
    }

    private Gdk.DragAction data_received (Gdk.DragContext context, Gtk.SelectionData data) {
        playlist_media_added (view, data.get_uris ());
        return Gdk.DragAction.COPY;
    }

}

public class Tuner.SortableCategory : Granite.Widgets.SourceList.ExpandableItem, Granite.Widgets.SourceListSortable {

    public SortableCategory (string name) {
        Object (name: name);
    }

    private bool allow_dnd_sorting () {
        return true;
    }
    private int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
        var item_a = a as SourceListItem;
        var item_b = b as SourceListItem;
        if (item_a == null || item_b == null)
            return 0;
        if (item_a.hint == ViewWrapper.Hint.PLAYLIST) {
            if (item_b.hint == ViewWrapper.Hint.PLAYLIST)
                return strcmp (item_a.name.collate_key (), item_b.name.collate_key ());
            return -1;
        }
        return 0;
    }

}

public class Tuner.SourceListRoot : Granite.Widgets.SourceList.ExpandableItem, Granite.Widgets.SourceListSortable {
    public SourceListRoot () {
        base ("SourceListRoot");
    }

    private bool allow_dnd_sorting () {
        return true;
    }

    private int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
        return 0;
    }
}

public class Tuner.SourceListView : Granite.Widgets.SourceList {

    Granite.Widgets.SourceList.ExpandableItem selections_category;
    Granite.Widgets.SourceList.ExpandableItem library_category;
    Granite.Widgets.SourceList.ExpandableItem genres_category;
    SortableCategory playlists_category;

    public signal void edited (GridView view, string new_name);
    public signal void item_action_activated (GridView view);
    public signal void selection_changed (Tuner.GridView view);
    public signal void activated ();
    public signal void playlist_rename_clicked (GridView view);


    public SourceListView (Gtk.Stack content_stack) {
        base (new SourceListRoot ());

        selections_category = new Granite.Widgets.SourceList.ExpandableItem (_("Selections"));
        selections_category.collapsible = false;
        selections_category.expanded = true;
        library_category = new Granite.Widgets.SourceList.ExpandableItem (_("Library"));
        library_category.collapsible = false;
        library_category.expanded = true;
        genres_category = new Granite.Widgets.SourceList.ExpandableItem (_("Genres"));
        genres_category.collapsible = true;
        genres_category.expanded = true;
        playlists_category = new SortableCategory (_("Playlists"));
        playlists_category.collapsible = true;
        playlists_category.expanded = true;


        this.root.add (selections_category);
        this.root.add (library_category);
        this.root.add (genres_category);
        this.root.add (playlists_category);
  
        this.root.expand_all (false, false);

        Gtk.TargetEntry uri_list_entry = { "text/uri-list", Gtk.TargetFlags.SAME_APP, 0 };
        enable_drag_dest ({ uri_list_entry }, Gdk.DragAction.COPY);
    }

   
    public SourceListEntry add_item (GridView view,
        string label,
        ViewWrapper.Hint hint,
        GLib.Icon icon,
        GLib.Icon? activatable_icon = null){


            var sourcelist_item = new SourceListItem (view, label, hint, icon, activatable_icon);

            sourcelist_item.activated.connect (() => {activated ();});
            sourcelist_item.edited.connect ((new_name) => {this.edited (sourcelist_item.view, new_name);});
            sourcelist_item.playlist_rename_clicked.connect ((view, item) => {
                playlist_rename_clicked (view);
                //Start_editing_item (item);
            });
            sourcelist_item.badge = @"$(view.content.item_count)";
            view.content.notify["item-count"].connect (() => {
                sourcelist_item.badge = @"$(view.content.item_count)";
            });
            
           

            switch (hint) {
                case ViewWrapper.Hint.NONE:
                    break;
                case ViewWrapper.Hint.SELECTION:
                    selections_category.add (sourcelist_item);
                    break;
                case ViewWrapper.Hint.FAVORITE_RESULTS:
                    library_category.add (sourcelist_item);
                    break;
                case ViewWrapper.Hint.SEARCH_RESULTS:
                    library_category.add (sourcelist_item);
                    break;
                case ViewWrapper.Hint.GENRE:
                    genres_category.add (sourcelist_item);
                    break;
                case ViewWrapper.Hint.PLAYLIST:
                    playlists_category.add (sourcelist_item);
                    break;
                default:
                    break;
            }


            return sourcelist_item;
        }

        public override void item_selected (Granite.Widgets.SourceList.Item? item) {
            if (item is Tuner.SourceListItem) {
                var sidebar_item = item as SourceListItem;
                selection_changed (sidebar_item.view);
            } 
        }

        private SourceListItem? get_playlist (GridView view) {
            foreach (var playlist in playlists_category.children) {
                if (playlist is SourceListItem) {
                    if (view == ((SourceListItem)playlist).view) {
                        return ((SourceListItem)playlist);
                    }
                }
            }
            return null;
        }

        public void remove_playlist (GridView view) {
            var playlist = get_playlist (view);
            if (playlist != null)
                playlists_category.remove (playlist);
        }

        public void change_playlist_name (GridView view, string new_name) {
            var playlist = get_playlist (view);
            if (playlist != null)
                playlist.name = new_name;
        }



}