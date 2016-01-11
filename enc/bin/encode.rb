#! /usr/bin/env ruby
# coding: utf-8

require 'time'
require 'json'
require 'open3'
require 'fileutils'

PROGNAME    = File.basename $0
FFPROBE     = '/usr/local/bin/ffprobe'
FFMPEG      = '/usr/local/bin/ffmpeg'
TMPDIR      = '/var/tmp'
HOME        = ENV['HOME']
CHINACHUDIR = "#{HOME}/chinachu"
RECJSON     = "#{CHINACHUDIR}/data/recorded.json"
ENCDIR      = "#{HOME}/enc"
LOCKFILE    = "#{ENCDIR}/logs/enc.lock"
LOGFILE     = "#{ENCDIR}/logs/#{Time.now.strftime('%Y%m%d')}.log"
ENCODEDDIR  = "#{ENCDIR}/encoded/latest"

def log *msgs
  File.open(LOGFILE, 'a') do |f|
    msgs.each do |msg|
      f.puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} #{msg}"
    end
  end
end

def lock
  Dir.mkdir LOCKFILE
rescue
  log "#{PROGNAME} is already running", "exit" 
  exit 1
end

def unlock
  Dir.rmdir LOCKFILE
end

def trap_signals
  ['HUP', 'INT', 'QUIT', 'TERM'].each do |signame|
    Signal.trap(signame) do
      log "Trap signal SIG #{signame}"
      unlock
      exit 1
    end
  end
end

def get_maps infile
  stdout, stderr, status = Open3.capture3 "#{FFPROBE} '#{infile}'"
  vmap = nil
  amap = nil

  stderr.scrub.split("\n").each do |line|
    if m = line.match(/Stream #(\d:\d\d?)\[.*mpeg2video/)
      vmap = m[1]
      break
    end
  end

  stderr.scrub.split("\n").each do |line|
    if m = line.match(/Stream #(\d:\d\d?)\[.*Audio: aac/)
      amap = m[1]
      break
    end
  end

  if not vmap or not amap
    log "No available map in #{infile}", "exit"
    unlock
    exit 1
  end

  "-map #{vmap} -map #{amap}"
end

def encode infile, outfile, maps
  log "Encoding #{infile} ..."
  options = "-i '#{infile}' #{maps} -vcodec libx264 -qmin 10 -vb 2000k -acodec libfdk_aac '#{outfile}'"
  `#{FFMPEG} #{options}`
  log "Finish! Output is #{outfile}"
end

def execute
  programs = File.open(RECJSON) { |f| JSON.load f }
  programs.each do |program|
    infile  = "#{CHINACHUDIR}/#{program['recorded'].gsub('./', '')}"
    outdir  = "#{ENCODEDDIR}/#{program['title'].gsub('/', '／')}"
    epnum   = sprintf('%02d', program['episode']) rescue 'XX'
    tmpfile = "#{TMPDIR}/ep#{epnum}_#{program['subTitle'].gsub('/', '／')}.mp4"
    outfile = "#{outdir}/ep#{epnum}_#{program['subTitle'].gsub('/', '／')}.mp4"

    next if File.exists?(outfile) or not File.exists?(infile)
    
    Dir.mkdir outdir if not Dir.exists? outdir

    encode infile, tmpfile, get_maps(infile)

    FileUtils.mv tmpfile, outfile
  end
end

## main
if $0 == __FILE__
  log "#{PROGNAME} start"
  lock
  trap_signals
  execute
  unlock
  log "#{PROGNAME} end"
end
