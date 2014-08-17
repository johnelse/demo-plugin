module Common = Rrdd_plugin.Common(struct let name = "visitor_count_plugin" end)

let get_cstruct path =
	let fd = Unix.openfile path [Unix.O_RDONLY] 0o400 in
	try
		if Unix.lseek fd 0 Unix.SEEK_SET <> 0 then failwith "lseek";
		let mapping = Bigarray.(Array1.map_file fd char c_layout false (-1)) in
		Cstruct.of_bigarray mapping
	with e ->
		Unix.close fd;
		raise e

let get_dss cstruct =
	let visitor_count = Cstruct.BE.get_uint64 cstruct 0 in
	[
		Rrd.Host,
		Ds.ds_make
			~name:"visitor_count"
			~description:"number of visitors"
			~value:(Rrd.VT_Int64 visitor_count)
			~ty:Rrd.Gauge
			~default:true
			~units:"visitors"
			()
	]

let () =
	Common.initialise ();
	let cstruct = get_cstruct "/dev/shm/visitor_count" in
	Common.main_loop
		~neg_shift:0.5
		~target:(Rrdd_plugin.Interdomain (0, 1))
		~protocol:Rrd_interface.V2
		~dss_f:(fun () -> get_dss cstruct)
