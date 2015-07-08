#!/usr/bin/env ruby
#
# Check DNF update plugin for nagios / icinga
#
# Author : Nicolas Gailly v1.0
# Works with DNF v1.0.0

require 'open3'

TITLE = "check_dnf"
VERSION = "1.0"

## Nagios / icinga output
CODES = { OK: 0, WARNING:  1, CRITICAL:  2, UNKNOWN: 3 }


def run cmd
    success = false
    output = nil
    Open3.popen3(cmd) do |inp,out,err,t|
        inp.close
        output = out.read.chomp
        out.close
        leave :UNKNOWN,"Command #{cmd} error : #{err}" unless t.value.success? 
    end
    output
end

def leave status, msg
    code = CODES[status]
    puts status.to_s + " - " + msg
    exit code
end

def check_updates
    cmd = "dnf updateinfo"
    output = run cmd
    
    if output =~ /^Updates Information Summary: (\w+)$/
        unless $1 =~ /available/
            leave :UNKNOWN,"DNF do not have update information summary available. Check with DNF"
        end
    else
        leave :OK,"DNF shows no updates to do !"
    end

    updates = Hash.new { |h,k| h[k] = 0 }
    code = :OK

    re = /(\d{1,4})\s+(\w+)\s+notice\(s\)$/
    output.split("\n").each do |line|
        next unless line.match re
        updates[$2] += $1.to_i
        code = :CRITICAL if $2 =~ /security/i
    end

    code = :WARNING if updates.size > 0 && code != :CRITICAL
    if updates.size == 0
        msg = "No updates to do on this host."
    else
        msg = updates.reduce([]) { |col,(k,v)| col << "#{v} #{k.downcase}"}.join(", ") + " update(s) to do."
    end
    return code,msg
end

begin
    code,msg = check_updates
    leave code,msg
rescue StandardError => e
    leave :UNKNOWN,"Unknown error : #{e}"
end
