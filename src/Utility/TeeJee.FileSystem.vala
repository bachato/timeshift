
/*
 * TeeJee.FileSystem.vala
 *
 * Copyright 2012-2018 Tony George <teejeetech@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */
 
namespace TeeJee.FileSystem{

	/* Convenience functions for handling files and directories */

	using TeeJee.Logging;
	using TeeJee.ProcessHelper;
	using TeeJee.Misc;


	public const int64 KB = 1000;
	public const int64 MB = 1000 * KB;
	public const int64 GB = 1000 * MB;
	public const int64 TB = 1000 * GB;
	public const int64 KiB = 1024;
	public const int64 MiB = 1024 * KiB;
	public const int64 GiB = 1024 * MiB;
	public const int64 TiB = 1024 * GiB;
	
	// path helpers ----------------------------
	
	public string file_parent(string file_path){
		return File.new_for_path(file_path).get_parent().get_path();
	}

	public string file_basename(string file_path){
		return File.new_for_path(file_path).get_basename();
	}

	public string path_combine(string path1, string path2){
		return GLib.Path.build_path("/", path1, path2);
	}

	public string remove_trailing_slash(string path){
		if (path.has_suffix("/")){
			return path[0:path.length - 1];
		}
		else{
			return path;
		}
	}
	
	// file helpers -----------------------------

	public bool file_exists (string file_path){
		/* Check if file exists */
		return (FileUtils.test(file_path, GLib.FileTest.EXISTS)
			&& !FileUtils.test(file_path, GLib.FileTest.IS_DIR));
	}

	public bool file_delete(string file_path){

		/* Check and delete file */

		try {
			var file = File.new_for_path (file_path);
			if (file.query_exists ()) {
				file.delete ();
			}
			return true;
		} catch (Error e) {
	        log_error (e.message);
	        log_error(_("Failed to delete file") + ": %s".printf(file_path));
	        return false;
	    }
	}

	public int64? file_line_count (string file_path){
		/* Count number of lines in text file returns null on error */

		try {
			long line_nums = 0;
			char symbol;

			File file = File.new_for_path(file_path);
			FileInputStream inStream = file.read();
			BufferedInputStream bis = new BufferedInputStream.sized(inStream,  (size_t) (1 * MiB));
			while((symbol = (char) bis.read_byte()) != -1) {
				if(symbol == '\n') {
					line_nums ++;
				}
			}
			bis.close();
			return line_nums;
		} catch(Error e) {
			log_error (e.message);
			log_error(_("Failed to read file") + ": %s".printf(file_path));
		}
		return null;
	}

	public string? file_read (string file_path){

		/* Reads text from file */

		string txt;
		size_t size;

		try{
			GLib.FileUtils.get_contents (file_path, out txt, out size);
			return txt;
		}
		catch (Error e){
	        log_error (e.message);
	        log_error(_("Failed to read file") + ": %s".printf(file_path));
	    }

	    return null;
	}

	public bool file_write (string file_path, string contents){

		/* Write text to file */

		try{

			dir_create(file_parent(file_path));
			
			var file = File.new_for_path (file_path);
			if (file.query_exists ()) {
				file.delete ();
			}
			
			var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream (file_stream);
			data_stream.put_string (contents);
			data_stream.close();
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			log_error(_("Failed to write file") + ": %s".printf(file_path));
			return false;
		}
	}

	public bool file_copy (string src_file, string dest_file){
		try{
			var file_src = File.new_for_path (src_file);
			if (file_src.query_exists()) {
				var file_dest = File.new_for_path (dest_file);
				file_src.copy(file_dest,FileCopyFlags.OVERWRITE,null,null);
				return true;
			}
		}
		catch(Error e){
	        log_error (e.message);
	        log_error(_("Failed to copy file") + ": '%s', '%s'".printf(src_file, dest_file));
		}

		return false;
	}

	public void file_move (string src_file, string dest_file){
		try{
			var file_src = File.new_for_path (src_file);
			if (file_src.query_exists()) {
				var file_dest = File.new_for_path (dest_file);
				file_src.move(file_dest,FileCopyFlags.OVERWRITE,null,null);
			}
			else{
				log_error(_("File not found") + ": '%s'".printf(src_file));
			}
		}
		catch(Error e){
	        log_error (e.message);
	        log_error(_("Failed to move file") + ": '%s', '%s'".printf(src_file, dest_file));
		}
	}

	public bool file_is_symlink(string file_path){

		try {
			var file = File.new_for_path (file_path);
			
			if (file.query_exists()) {

				var info = file.query_info("%s".printf(FileAttribute.STANDARD_TYPE), FileQueryInfoFlags.NOFOLLOW_SYMLINKS); // don't follow symlinks

				var file_type = info.get_file_type();

				return (file_type == FileType.SYMBOLIC_LINK);
			}
		}
		catch (Error e) {
	        log_error (e.message);
	    }
	    
		return false;
	}

	public bool file_gzip (string src_file){
		
		string dst_file = src_file + ".gz";
		file_delete(dst_file);
		
		string cmd = "gzip '%s'".printf(escape_single_quote(src_file));
		string std_out, std_err;
		exec_sync(cmd, out std_out, out std_err);
		
		return file_exists(dst_file);
	}

	public string file_resolve_executable_path(string file_path){

		if (file_path.has_prefix("/")){
			return file_path;
		}
		else if (!file_path.contains("/")){
			return GLib.Environment.find_program_in_path(file_path);
		}
		else if (file_path.has_prefix("./")){
			return path_combine(GLib.Environment.get_current_dir(), file_path[2:file_path.length]);
		}
		else if (file_path.has_prefix("../")){
			return path_combine(file_parent(GLib.Environment.get_current_dir()), file_path[3:file_path.length]);
		}
		else {
			return path_combine(GLib.Environment.get_current_dir(), file_path);
		}
	}
	
	// file info -----------------

	public string file_get_symlink_target(string file_path){
		try{
			FileInfo info;
			File file = File.parse_name (file_path);
			if (file.query_exists()) {
				info = file.query_info("%s".printf(FileAttribute.STANDARD_SYMLINK_TARGET), 0);
				return info.get_symlink_target();
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
		
		return "";
	}

	// directory helpers ----------------------
	
	public bool dir_exists (string dir_path){
		/* Check if directory exists */
		return ( FileUtils.test(dir_path, GLib.FileTest.EXISTS) && FileUtils.test(dir_path, GLib.FileTest.IS_DIR));
	}
	
	public bool dir_create (string dir_path, bool show_message = false){

		/* Creates a directory along with parents */

		try{
			var dir = File.parse_name (dir_path);
			
			if (dir.query_exists () == false) {
				
				bool ok = dir.make_directory_with_parents (null);
				
				if (show_message){
					if (ok){
						log_msg(_("Created directory") + ": %s".printf(dir_path));
					}
					else{
						log_error(_("Failed to create directory") + ": %s".printf(dir_path));
					}
				}
			}
			
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			log_error(_("Failed to create directory") + ": %s".printf(dir_path));
			return false;
		}
	}

	// delete an empty directory
	public static bool dir_empty_delete(string path) {
		File dirf = File.new_for_path(path);
		try {
			if (dirf.query_file_type(FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
				return dirf.delete(); // only succeeds, if the dir is empty
			}
		} catch(Error ioe) {
			if(ioe.matches(IOError.quark(), IOError.NOT_FOUND)) {
				// directory does not exist
				return true;
			}
		}
		return false;
	}

	public static bool dir_delete_recursive(string dir) {
		File f = File.new_for_path(dir);
		if(f.query_exists()) {
			try {
				FileEnumerator enumerator = f.enumerate_children(FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				FileInfo info;
				while ((info = enumerator.next_file()) != null) {
					string name = info.get_name();
					if(info.get_file_type() == FileType.DIRECTORY) {

						// ignore . and ..
						if(name == "." || name == "..") {
							continue;
						}

						if(!dir_delete_recursive(dir + "/" + name)) {
							return false;
						}
					} else {
						File file = File.new_for_path(dir + "/" + name);
						file.delete();
					}
				}
				f.delete();
			} catch(Error err) {
				log_error("Can not enumerate folder %s".printf(dir));
				return false;
			}
		}
		return true;
	}

	public static bool dir_delete(string dir_path, bool show_message = false) {

		/* Recursively deletes directory along with contents */

		bool status = dir_delete_recursive(dir_path);

		if (show_message){
			if (status){
				log_msg(_("Deleted directory") + ": %s".printf(dir_path));
			}
			else{
				log_error(_("Failed to delete directory") + ": %s".printf(dir_path));
			}
		}

		return status;
	}

	public bool dir_is_empty (string dir_path){

		/* Check if directory is empty */

		try{
			bool is_empty = true;
			var dir = File.parse_name (dir_path);
			if (dir.query_exists()) {
				FileInfo info;
				var enu = dir.enumerate_children (FileAttribute.STANDARD_NAME, 0);
				while ((info = enu.next_file()) != null) {
					is_empty = false;
					break;
				}
			}
			return is_empty;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	public Gee.ArrayList<string> dir_list_names(string path){
		
		var list = new Gee.ArrayList<string>();
		
		try
		{
			File f_home = File.new_for_path (path);
			FileEnumerator enumerator = f_home.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
			FileInfo file;
			while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				list.add(name);
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		//sort the list
		CompareDataFunc<string> entry_compare = (a, b) => {
			return strcmp(a,b);
		};
		list.sort((owned) entry_compare);

		return list;
	}
	
	public bool chown(string dir_path, string user, string group = user){
		string cmd = "chown %s:%s -R '%s'".printf(user, group, escape_single_quote(dir_path));
		int status = exec_sync(cmd, null, null);
		return (status == 0);
	}
	
	// misc --------------------

	public string format_file_size (
		uint64 size, bool binary_units = false,
		string unit = "", bool show_units = true, int decimals = 1){
			
		uint64 unit_k = binary_units ? 1024 : 1000;
		uint64 unit_m = binary_units ? 1024 * unit_k : 1000 * unit_k;
		uint64 unit_g = binary_units ? 1024 * unit_m : 1000 * unit_m;
		uint64 unit_t = binary_units ? 1024 * unit_g : 1000 * unit_g;

		//log_debug("size: %'lld".printf(size));

		string txt = "";
		
		if ((size > unit_t) && ((unit.length == 0) || (unit == "t"))){
			txt += ("%%'0.%df".printf(decimals)).printf(size / (1.0 * unit_t));
			if (show_units){
				txt += " %sB".printf(binary_units ? "Ti" : "T");
			}
		}
		else if ((size > unit_g) && ((unit.length == 0) || (unit == "g"))){
			txt += ("%%'0.%df".printf(decimals)).printf(size / (1.0 * unit_g));
			if (show_units){
				txt += " %sB".printf(binary_units ? "Gi" : "G");
			}
		}
		else if ((size > unit_m) && ((unit.length == 0) || (unit == "m"))){
			txt += ("%%'0.%df".printf(decimals)).printf(size / (1.0 * unit_m));
			if (show_units){
				txt += " %sB".printf(binary_units ? "Mi" : "M");
			}
		}
		else if ((size > unit_k) && ((unit.length == 0) || (unit == "k"))){
			txt += ("%%'0.%df".printf(decimals)).printf(size / (1.0 * unit_k));
			if (show_units){
				txt += " %sB".printf(binary_units ? "Ki" : "K");
			}
		}
		else{
			txt += "%'0lu".printf(size);
			if (show_units){
				txt += " B";
			}
		}

		//log_debug("converted: %s".printf(txt));

		return txt;
	}

	public string escape_single_quote(string file_path){
		
		return file_path.replace("'","'\\''");
	}
	
	// dep: chmod
	public int chmod(string file, string permission){

		string cmd = "chmod %s '%s'".printf(permission, escape_single_quote(file));
		return exec_sync (cmd, null, null);
	}
}
