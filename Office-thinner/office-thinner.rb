#!/usr/bin/env ruby
# -*- coding:utf-8 -*-

# TODO: Check same file with soft link
# TODO: Trim same file by apfs clone

require 'set'
require 'find'
require 'digest'
require 'fileutils'

TRASH = "#{ENV["HOME"]}/.Trash/Office/"

WORD_PATH = '/Applications/Microsoft Word.app'
EXCEL_PATH = '/Applications/Microsoft Excel.app'
ONENOTE_PATH = '/Applications/Microsoft OneNote.app'
OUTLOOK_PATH =   '/Applications/Microsoft Outlook.app'
POWERPOINT_PATH = '/Applications/Microsoft PowerPoint.app'

PATHS = [WORD_PATH, EXCEL_PATH, ONENOTE_PATH, OUTLOOK_PATH, POWERPOINT_PATH]
@target_path = nil
@trim_paths = []

def find_all_files_without_prefix(dir)
  set = Set.new
  Find.find(dir) do |filename|
    unless File.directory? filename or File.symlink? filename
      set << filename[dir.length, filename.length] if filename != dir
    end
  end
  return set
end

def find_same_files(dir1, dir2)
  set1 = find_all_files_without_prefix(dir1)
  set2 = find_all_files_without_prefix(dir2)
  set = set1 & set2
  same_files = set.select do |filename|
    File.lstat(dir1+filename).ino != File.lstat(dir2+filename).ino \
      and FileUtils.compare_file(dir1+filename, dir2+filename)
  end
  return same_files
end

def backup_file(filename)
  dest_filename = TRASH + filename
  FileUtils.mkdir_p File.dirname(dest_filename)
  puts "Move #{filename} to #{dest_filename}"
  FileUtils.mv filename, dest_filename
end

def trim_all_same_files(target_dir, dir)
  same_files = find_same_files(target_dir, dir)
  same_files.each do |filename|
    backup_file dir+filename
    FileUtils.ln(target_dir+filename, dir+filename)
  end
end


def main
  if Process.euid != 0
    puts "Need root privilege, Please run: sudo ruby #{__FILE__}"
    exit 1
  end

  PATHS.each do |pathname|
    if Dir.exist?(pathname)
      if @target_path
        @trim_paths << pathname
      else
        @target_path = pathname
      end
    end
  end

  unless @target_path
    puts "Don't exist path in #{PATHS}"
    exit 1
  end

  puts "Trim #{@trim_paths} with #{@target_path}"
  @trim_paths.each do |pathname|
    puts "#{@target_path}, #{pathname}"
    trim_all_same_files(@target_path, pathname)
  end

  puts "Office thinning completed!"
  puts "Backup files in #{TRASH}, you view or delete the files later by Finder Trash."
end

if __FILE__ == $0
  main
end
