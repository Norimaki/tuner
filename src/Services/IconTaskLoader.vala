public class IconTaskLoader : Object {
    private static AsyncQueue<IconTask> jobs;
    private static Thread<void>[] threads;
    private static uint32 bulk_jobs_counter;

    private static void exit () {
        jobs.push_front (new IconTask.with_exit ());
    }

    public static void run () {
        //debug (@"#gui $(monotonic_time.to_string ("%"+int64.FORMAT))");
        bulk_jobs_counter = 0;
        jobs = new AsyncQueue<IconTask> ();
        var n = get_num_processors (); //Available since:	2.36
        threads = new Thread<void>[n];
        int i;
        for (i = 0; i < n; i++) {
            threads[i] = new Thread<void> (@"thread_$(i.to_string ("%d"))", do_jobs);
        }
    }

    public static void stop () {
        foreach (Thread<void> t in threads) {
            exit();
        }
    }

    private static void do_jobs () {
        while (true) {
            var a = jobs.pop ();
            if (a.exit) break;

            //a.queued = false;
            a.started = true;

            bool cancel = false;
            var n = GLib.Timeout.add (4096, () => {
                a.cancel_job();
                cancel = true;
                return false;
            });

            a.do_job();
            if (!cancel) Source.remove (n);

            //a.finallized = true;

            //var n_jobs = jobs.length () + threads.length ;
            //if (n_jobs < 1 ){
              // Tuner.DebugNot.create("IconTaskLoader","0 jobs on tasks");
               // bulk_jobs_counter = 0;
            //}

            //var n_jobs = jobs.length () + threads.length - 1;
            //if (n_jobs == 0 ){
            //    on_empty ();
            //} 
        }
    }

    public static void on_empty (){
        //Tuner.DebugNot.create("IconTaskLoader","empty");
        //bulk_jobs_counter = 0;
    }

    public static bool sort_jobs (GenericArray<IconTask> icon_tasks) {
        //Tuner.DebugNot.create("IconTaskLoader","sort_jobs");

        var n_jobs = jobs.length () + threads.length;
        if (n_jobs <1 ){
          // Tuner.DebugNot.create("IconTaskLoader","0 jobs on sort");
           bulk_jobs_counter = 0;
        }
        //else{
        //    Tuner.DebugNot.create("IconTaskLoader",@"$(n_jobs.to_string ("%d")) jobs on sort");
        //}


        bool need_sort = false;
        var l = icon_tasks.length;
        uint32 i = 0; 
        icon_tasks.foreach ((icon_task)=>{
            if (!icon_task.started && !icon_task.finallized){
            icon_task.priority  = {bulk_jobs_counter, l - i};
            need_sort = true;
            }
            i = i + 1;
        });

        if (need_sort){
            //Tuner.DebugNot.create("IconTaskLoader","need_sort");
            bulk_jobs_counter = bulk_jobs_counter + 1;
        }
        return need_sort;
       
    }

    public static void bulk_add (GenericArray<IconTask> icon_tasks) {
        if (sort_jobs (icon_tasks)){
            GLib.Idle.add (() => {
                icon_tasks.foreach ((icon_task)=>{
                    add_sorted (icon_task);
                });
                return false;
            });
        }
    }

    public static int SortFunc (IconTask a, IconTask b) {
        if (b.priority.major > a.priority.major){
            return +1;
        }
        else if (b.priority.major < a.priority.major){
            return -1;
        }
        else{
            if (b.priority.minor > a.priority.minor){
                return +1;
            }
            else if (b.priority.minor < a.priority.minor){
                return -1;
            }
            else{
                return 0;
            }
        }
    }

    public static void sort (GenericArray<IconTask> icon_tasks) {

        if (sort_jobs (icon_tasks)){
            //Tuner.DebugNot.create("loader","sorting");
            jobs.sort (SortFunc);
        }
    }

    public static void add_sorted (IconTask a) {
        //if (!a.queued && !a.started && !a.finallized){
        if (!a.started && !a.finallized){
            //a.queued = true;
            jobs.push_sorted (a, SortFunc);
        }
    }

    public static void add (IconTask a) {
        //if (!a.queued && !a.started && !a.finallized){
        if (!a.started && !a.finallized){
            //a.queued = true;
            jobs.push_front (a);
        }
    }

   // private static void remove (IconTask a) {
     //   jobs.remove (a);
        //a.queued = false;
    //}

    public static void cancel (IconTask a) {
        //if (a.queued) {
        if (!a.started) {
            //IconTaskLoader.remove(a);
            jobs.remove (a);
        }
        else if (!a.finallized){
            a.cancel_job();
        }
    }
}