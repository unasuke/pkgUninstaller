# pkgUninstaller -OS X app uninstaller-
#     Copyright (C) 2014  Yusuke Nakamura

#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.

#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.

#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "optparse"
require "fileutils"
require "shell"

#引数
# -n , --noop 実際のファイル削除は行わず、操作対象のファイルを出力する
# -u , --unlink pkgID 指定されたpkgを削除する
# -s , --search keyword keywordで検索を行い、検索結果から削除するか否か問う
# -q , --quiet 削除されたファイルとディレクトリの数のみ出力
# -h , --help コマンド一覧を出力する。引数が空の場合も出力する

OptionParser.new do |parser|
  #引数で受け取ったpkgIDを格納
  parser.on("-u" , "--unlink PKGID" , "Unlink PKGID."){|v| $pkgid = v; $unlink = true }

  #引数で受け取ったキーワードを格納
  parser.on("-s" , "--search KEYWORD" , "Search pkg."){|v| $keyword = v; $search = true }

  #no operationフラグを立てる
  parser.on("-n" , "--noop" , "No operation mode."){|v| $noop = v }

  #quietフラグを立てる
  parser.on("-q" , "--quiet" , "Quiet mode."){|v| $quiet = v }

  #コマンド一覧を出力して終了
  #parser.on("-h" , "--help" , "Show this message."){puts parser; exit}

  begin
    parser.parse!(ARGV)
  end
end

###下準備###

#初期化
sh = Shell.new

#インストールされているpkgの一覧を取得
pkgs = sh.system("pkgutil" , "--pkgs")

#改行ごとに区切り配列に格納し直す
pkgArray = pkgs.to_s.split("\n")

###削除###
if !!$unlink
  #そもそも引数で受け取ったパッケージが存在するか否か
  pkg_existence = false

  pkg_existence = pkgArray.include?($pkgid)

  #パッケージが存在しない場合はその旨を表示し終了
  unless !!pkg_existence
    puts "package-id is wrong.\nexit this program."
    exit
  end

  #インストールされているファイル群の絶対パスを取得し、行ごとの配列にする
  pkg_info = sh.system("pkgutil", "--pkg-info", $pkgid).to_s.split("\n")
  sh.check_point()

  #削除対象となるパスを抽出
  pkg_info[2]["volume: "] = ""
  pkg_info[3]["location: "] = ""
  unless pkg_info[3].eql?("")
    pkg_info[3] = pkg_info[3] + "/"
  end
  pkg_path = pkg_info[2] + pkg_info[3]

  #インストールされたファイル、ディレクトリを取得し、深さ(文字数)で降順ソート
  pkg_file_path = sh.system("pkgutil", "--only-files", "--files", $pkgid).to_s.split("\n")
  sh.check_point()
  pkg_file_path.sort!{|a,b| b.size <=> a.size}
  #puts pkg_file_path

  pkg_dir_path = sh.system("pkgutil", "--only-dirs", "--files", $pkgid).to_s.split("\n")
  sh.check_point()
  pkg_dir_path.sort!{|a,b| b.size <=> a.size}
  #puts pkg_dir_path

  #削除数カウント
  file_deleted = 0
  dir_deleted = 0

  #ファイルの削除を行う
  for delete_file_name in pkg_file_path
    FileUtils.remove(pkg_path + delete_file_name, noop: !!$noop)
    puts "delete #{pkg_path + delete_file_name}" unless !!$quiet
    file_deleted += 1
  end

  #ディレクトリの削除を行う(空ディレクトリのみ)
  for delete_dir_name in pkg_dir_path
    begin
      FileUtils.rmdir(pkg_path + delete_dir_name, noop: !!$noop)
      puts "delete #{pkg_path + delete_dir_name}" unless !!$quiet
      dir_deleted += 1

      if Dir.entries(pkg_path + delete_dir_name).size > 2
        #noopが指定されているときはErrono::ENOTEMPTYが呼び出されないため空かどうかがわからない
        puts "#{pkg_path + delete_dir_name} is not empty." unless !!$quiet
      end

    rescue Errno::ENOTEMPTY => e
      #空でないディレクトリは削除しない
      #puts "#{pkg_path + delete_dir_name} is not empty."
      dir_deleted -= 1

    rescue Errno::ENOENT => e
      #ディレクトリが存在しない
      puts "#{pkg_path + delete_dir_name} is not existence."
      dir_deleted -= 1
    end
  end

  #pkgの情報を削除
  unless !!$noop
    sh.system("pkgutil", "--forget", $pkgid)
    sh.check_point()
  end

  puts "#{file_deleted} files and #{dir_deleted} directories deleted."

end

###検索###
if !!$search
  #pkgArray内を検索して一致するものを出力し終了
  pkgArray.each do |pkg|
    puts pkg if pkg.include?($keyword)
  end
end
