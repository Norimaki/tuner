public class Tuner.DebugNot : Object{

    public static void create (string c, string b){
        new DebugNot (c, b);
    }
    private DebugNot (string c, string b){
    var notification = new GLib.Notification(c);
    notification.set_body(b);
    string id = c+GLib.Random.int_range(0,100000000).to_string("%d");
    Application.instance.send_notification(id, notification);
    }
}