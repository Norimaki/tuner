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

public class Tuner.Application : Gtk.Application {

    public GLib.Settings settings { get; construct; }
    public PlayerController player { get; construct; }
    public string? cache_dir { get; construct; }
    public string? data_dir { get; construct; }
    public string? tmp_dir { get; construct; }
    public string? lock_tmp_dir { get; construct; }

    public Window window;

    public const string APP_VERSION = "1.5.0";
    public const string APP_ID = "com.github.louis77.tuner";
    public const string STAR_CHAR = "★ ";
    public const string UNSTAR_CHAR = "☆ ";

    private const ActionEntry[] ACTION_ENTRIES = {
        { "resume-window", on_resume_window }
    };

    public Application () {
        Object (
            application_id: APP_ID,
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    construct {
        GLib.Intl.setlocale (LocaleCategory.ALL, "");
        GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        GLib.Intl.textdomain (GETTEXT_PACKAGE);

        settings = new GLib.Settings (this.application_id);
        player = new PlayerController ();

        cache_dir = Path.build_filename (Environment.get_user_cache_dir (), application_id);
        ensure_dir (cache_dir);

        data_dir = Path.build_filename (Environment.get_user_data_dir (), application_id);
        ensure_dir (data_dir);

        tmp_dir = Path.build_filename (Environment.get_tmp_dir (), application_id);
        ensure_dir (tmp_dir);

        lock_tmp_dir = Path.build_filename (tmp_dir, "lock");
        clean_dir (lock_tmp_dir);
        ensure_dir (lock_tmp_dir);

        add_action_entries(ACTION_ENTRIES, this);
    }

    public static Application _instance = null;

    public static Application instance {
        get {
            if (_instance == null) {
                _instance = new Application ();
            }
            return _instance;
        }
    }

    protected override void activate() {
        if (window == null) {
            window = new Window (this, player);
            add_window (window);
            DBus.initialize ();
        } else {
            window.present ();
        }

    }

    private void on_resume_window() {
        window.present();
    }

    private static void clean_dir (string path) {
        FileInfo? info = null;
        FileEnumerator? enumerator = null;
        File folder = File.new_for_path (path);
        try {
            enumerator = folder.enumerate_children (
                "standard::*",
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,null);
    
                while ((info = enumerator.next_file ()) != null) {
                    try {
                        File file = folder.resolve_relative_path (info.get_name ());
                        file.delete();
                    } catch (Error e) {
                    }
                }
        } catch (Error e) {
        }
    }

    private static void ensure_dir (string path) {
        if (!FileUtils.test(path, FileTest.EXISTS)) {
            var ret = DirUtils.create_with_parents (path, 0700);
            if (ret != 0) {
                warning ("%s couldn't be created. Error: %d", path, GLib.FileUtils.error_from_errno (GLib.errno));
            }
        }
        if (!FileUtils.test(path, FileTest.IS_DIR)) {
            error (@"$(path) is not a dir");
        }
    }

}

