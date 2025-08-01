
/*
 * LinuxDistro.vala
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;

public class LinuxDistro : GLib.Object{

	/* Class for storing information about Linux distribution */

	public string dist_id = "";
	public string description = "";
	public string release = "";
	public string codename = "";

	public LinuxDistro(){
		dist_id = "";
		description = "";
		release = "";
		codename = "";
	}

	public string full_name(){
		
		if (dist_id == ""){
			return "";
		}
		else{
			string val = "";
			val += dist_id;
			val += (release.length > 0) ? " " + release : "";
			val += (codename.length > 0) ? " (" + codename + ")" : "";
			return val;
		}
	}

	public static LinuxDistro get_dist_info(string root_path){

		/* Returns information about the Linux distribution
		 * installed at the given root path */


		/*
		try to read from /etc/lsb-release
		example content:

		DISTRIB_ID=Ubuntu
		DISTRIB_RELEASE=13.04
		DISTRIB_CODENAME=raring
		DISTRIB_DESCRIPTION="Ubuntu 13.04"
		*/
		LinuxDistro? info = read_info_file(root_path + "/etc/lsb-release");
		if(info != null) {
			return info;
		}

		/*
		fallback to /etc/os-release
		example content:

		NAME="Ubuntu"
		VERSION="13.04, Raring Ringtail"
		ID=ubuntu
		ID_LIKE=debian
		PRETTY_NAME="Ubuntu 13.04"
		VERSION_ID="13.04"
		HOME_URL="http://www.ubuntu.com/"
		SUPPORT_URL="http://help.ubuntu.com/"
		BUG_REPORT_URL="http://bugs.launchpad.net/ubuntu/"
		*/
		return read_info_file(root_path + "/etc/os-release") ?? new LinuxDistro();
	}

	// read a generic info file like /etc/os-release or /etc/lsb-release
	private static LinuxDistro? read_info_file(string file_path) {
		string? dist_file_cont = file_read(file_path);
		if(dist_file_cont == null || dist_file_cont.length == 0) {
			return null;
		}

		LinuxDistro info = new LinuxDistro();
		string[] lines = dist_file_cont.split("\n");

		foreach(string line in lines){
			// split for 3 to detect if there are to many
			string[] linesplit = line.split("=", 3);

			if (linesplit.length != 2){ continue; }

			string key = linesplit[0].strip();
			string val = linesplit[1].strip();

			// removing leading "
			if (val.has_prefix("\"")) {
				val = val[1:val.length];
			}

			// remove trailing "
			if (val.has_suffix("\"")) {
				val = val[0:val.length-1];
			}

			switch (key) {
				case "ID":
				case "DISTRIB_ID":
					info.dist_id = val;
					break;
				case "VERSION_ID":
				case "DISTRIB_RELEASE":
					info.release = val;
					break;
				case "VERSION_CODENAME":
				case "DISTRIB_CODENAME":
					info.codename = val;
					break;
				case "PRETTY_NAME":
				case "DISTRIB_DESCRIPTION":
					info.description = val;
					break;
			}
		}
		return info;
	}

	public string dist_type {
		
		owned get{
			
			if (dist_id.down() in "fedora rhel rocky centos almalinux"){
				return "redhat";
			}
			else if (dist_id.down().contains("manjaro") || dist_id.down().contains("arch")){
				return "arch";
			}
			else if (dist_id.down().contains("ubuntu") || dist_id.down().contains("debian")){
				return "debian";
			}
			else{
				return "";
			}

		}
	}
}


