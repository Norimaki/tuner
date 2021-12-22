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


[DBus (name = "org.mpris.MediaPlayer2.Player", timeout = 120000)]
public interface Tuner.DBus.IMediaPlayer2Player : GLib.Object {

	[DBus (name = "Next")]
	public abstract void next() throws DBusError, IOError;

	[DBus (name = "Previous")]
	public abstract void previous() throws DBusError, IOError;

	[DBus (name = "Pause")]
	public abstract void pause() throws DBusError, IOError;

	[DBus (name = "PlayPause")]
	public abstract void play_pause() throws DBusError, IOError;

	[DBus (name = "Stop")]
	public abstract void stop() throws DBusError, IOError;

	[DBus (name = "Play")]
	public abstract void play() throws DBusError, IOError;

	[DBus (name = "Seek")]
	public abstract void seek(int64 Offset) throws DBusError, IOError;

	[DBus (name = "SetPosition")]
	public abstract void set_position(ObjectPath TrackId, int64 Position) throws DBusError, IOError;

	[DBus (name = "OpenUri")] 
	public abstract void open_uri(string Uri) throws DBusError, IOError;

	[DBus (name = "Seeked")]
	public signal void seeked(int64 Position);

	[DBus (name = "PlaybackStatus")] // s
	public abstract Variant playback_status {owned get;}

	[DBus (name = "LoopStatus")]
	public abstract string loop_status { owned get; }

	[DBus (name = "Rate")]
	public abstract double rate {  get; set; }

	[DBus (name = "Shuffle")]
	public abstract bool shuffle {  get; set; }

	[DBus (name = "Metadata")] // a{sv} 
	public abstract Variant metadata { owned get; }

	[DBus (name = "Volume")]
	public abstract double volume {  get; set; }

	[DBus (name = "Position")]
	public abstract int64 position {
	    get;
	}

	[DBus (name = "MinimumRate")]
	public abstract double minimum_rate {  get; set; }

	[DBus (name = "MaximumRate")]
	public abstract double maximum_rate {  get; set; }

	[DBus (name = "CanGoNext")]
	public abstract bool can_go_next {  get; }

	[DBus (name = "CanGoPrevious")]
	public abstract bool can_go_previous {  get; }

	[DBus (name = "CanPlay")] // b
	public abstract Variant can_play {  owned get; }

	[DBus (name = "CanPause")] // b
	public abstract Variant can_pause {  owned get; }

	[DBus (name = "CanSeek")]
	public abstract bool can_seek {  get; }

	[DBus (name = "CanControl")]
	public abstract bool can_control {  get; }
}

[DBus (name = "org.mpris.MediaPlayer2", timeout = 120000)]
public interface Tuner.DBus.IMediaPlayer2 : GLib.Object {

	[DBus (name = "Raise")]
	public abstract void raise() throws DBusError, IOError;

	[DBus (name = "Quit")]
	public abstract void quit() throws DBusError, IOError;

	[DBus (name = "CanQuit")]
	public abstract bool can_quit {  get; }

	[DBus (name = "Fullscreen")]
	public abstract bool fullscreen {  get; set; }

	[DBus (name = "CanSetFullscreen")]
	public abstract bool can_set_fullscreen {  get; }

	[DBus (name = "CanRaise")]
	public abstract bool can_raise {  get; }

	[DBus (name = "HasTrackList")]
	public abstract bool has_track_list {  get; }

	[DBus (name = "Identity")]
	public abstract string identity { owned get; }

	[DBus (name = "DesktopEntry")]
	public abstract string desktop_entry { owned get; }

	[DBus (name = "SupportedUriSchemes")]
	public abstract string[] supported_uri_schemes { owned get; }

	[DBus (name = "SupportedMimeTypes")]
	public abstract string[] supported_mime_types { owned get; }
}

//[DBus (name = "org.mpris.MediaPlayer2.TrackList", timeout = 120000)]
public interface Tuner.DBus.IMediaPlayer2TrackList : GLib.Object {

	[DBus (name = "GetTracksMetadata")]
	public abstract HashTable<string, Variant>[] get_tracks_metadata (ObjectPath[] TrackIds) throws DBusError, IOError;

	[DBus (name = "AddTrack")]
	public abstract void add_track (string Uri, ObjectPath AfterTrack, bool SetAsCurrent) throws DBusError, IOError;

	[DBus (name = "RemoveTrack")]
	public abstract void remove_track (ObjectPath TrackId) throws DBusError, IOError;

	[DBus (name = "GoTo")]
	public abstract void go_to (ObjectPath TrackId) throws DBusError, IOError;

	[DBus (name = "TrackListReplaced")]
	public signal void track_list_replaced(ObjectPath[] Tracks, ObjectPath CurrentTrack);

	[DBus (name = "TrackAdded")]
	public signal void track_added(HashTable<string, Variant> Metadata, ObjectPath AfterTrack);
	
	[DBus (name = "TrackRemoved")]
	public signal void track_removed(ObjectPath TrackId);

	[DBus (name = "TrackMetadataChanged")]
	public signal void track_metada_changed(ObjectPath TrackId, HashTable<string, Variant> Metadata);

	[DBus (name = "Tracks")]
	public abstract ObjectPath[] tracks {  get; } //Track_Id_List

	[DBus (name = "CanEditTracks")]
	public abstract bool can_edit_tracks {  get; } 

}