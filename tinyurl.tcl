# tinyurl.tcl
# eggdrop interface to http://pixor.net/tiny
# 0.1
#
# instructions:
# run sql: create table urls ( id int(11) not null auto_increment primary key, url text not null, date_posted datetime not null, nick varchar(100) not null, channel varchar(255) not null);
# edit mysql connection in proc saveurl
# load into your eggdrop bot

package require http
package require sql

bind pubm -|- "* *" checkurl
bind pub - !tinyurl tinyurl

proc checkurl {nick host handle chan text} {
	set response ""
	while {[regexp -nocase {([a-z]+://[^\s>]+)(.*)$} $text all_matches myurl rest]} {
		saveurl $myurl $nick $chan
		if {[string bytelength $myurl] > 50} {
			#tinyurl $nick $host $handle $chan $myurl
			set out [maketiny $myurl $nick $chan]
			if {[string bytelength $out] > 0} {
				set response "$response  $out"
			}
		}
		set text $rest
	}
	if {[string bytelength $response] > 0} {
		putserv "PRIVMSG $chan :\[$nick\]$response"
	}
}

proc maketiny {url nick chan} {
    set user_url $url
	set url "http://pixor.net/tiny/"
    set postdata [http::formatQuery url $user_url submit submit]
    set response [http::geturl $url -query $postdata]
    set lines [http::data $response]
    http::cleanup $response
    foreach line [split $lines \n] {
      if {[regexp -nocase {(http://pixor.net/tiny/[a-z0-9]+)} $line all_matches myurl]} {
		putlog "tinyurl created for $nick: $myurl"
		return $myurl
	  }
    }
	putlog "tinyurl failed for $nick: $user_url"
}

proc tinyurl {nick host handle chan args} {
  if {[lindex $args 0] != ""} {
	  set url [lindex $args 0]
	  maketiny $url $nick $chan
	  saveurl $url $nick $chan
  }
} 

proc saveurl {url nick chan} {
	set host "localhost"
	set user "username"
	set pass "password"
	set dbname "dbname"
	set conn [sql connect $host $user $pass]
	sql selectdb $conn $dbname
	
	regsub {'} $url {\\'} url
	regsub {'} $nick {\\'} nick
	regsub {'} $chan {\\'} chan

	set mysql "INSERT INTO urls (url, date_posted, nick, channel) VALUES ('$url', NOW(), '$nick', '$chan')"
	set res [catch {sql query $conn $mysql} msg]
	if {$res == 0} {
		puts "Error inserting: $msg"
	}
	sql endquery $conn
	sql disconnect $conn
}

putlog "tinyurl.tcl loaded"
