#!/usr/bin/perl
# A virtualbox fence agent for cman and pacemaker, using VBoxManage.
# Author:
#        klwang (http://klwang.info)
# Note:
#        authorized_keys configuration are required
#        just for test, enjoy it!
#
#  yum install -y perl-Data-Dumper.x86_64
#  ln -s '/drives/c/Program Files/Oracle/VirtualBox/VBoxManage.exe' /usr/bin/VBoxManage
#  ln -s '/cygdrive/c/Program Files/Oracle/VirtualBox/VBoxManage.exe' /usr/bin/VBoxManage
#  


use Data::Dumper;
use Getopt::Std;
use Getopt::Long;
use IPC::Open3;

my $ME = $0;

END {
  defined fileno STDOUT or return;
  close STDOUT and return;
  warn "$ME: failed to close standard output: $!\n";
  $? ||= 1;
}

# Get the program name from $0 and strip directory names
$_=$0;
s/.*\///;
my $pname = $_;

$opt_o    = 'reboot';       # Default fence action
$opt_u    = 'root';
$exit     = 0;
#$vboxcmd  = '"/drives/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"';
# ln -s '/drives/c/Program Files/Oracle/VirtualBox/VBoxManage.exe' /usr/bin/VBoxManage
$vboxcmd  = '/usr/bin/VBoxManage';
#$sshcmd   = '/usr/bin/ssh';
$sshcmd   = '/bin/echo';
$host     = `uname -n`;
chomp ($host);

sub usage
{
    print "Usage:\n\n";
    print "$pname [options]\n\n";
    print "Options:\n";
    print "  -s <string>      ipaddr (vbox server)\n";
    print "  -p <string>      nodename (guest name)\n";
    print "  -o <string>      action: reboot (default), off, on, list or status\n";
    print "  -u <string>      login (default=root)\n";
    print "  -h <string>      help\n";
    print "  -v               version\n";
    exit 0;
}

sub print_metadata
{
print '<?xml version="1.0" ?>
<resource-agent name="fence_virtualbox" shortdesc="klwang\'s virtualbox fence agent, work both for cman and pacemaker">
<longdesc>
The schema come from fence_pcmk, http://www.clusterlabs.org
Some functions come from fence_vbox, http://code.google.com/p/fencevbox/
</longdesc>
<vendor-url>http://klwang.info</vendor-url>
<parameters>
        <parameter name="action" unique="1">
                <getopt mixed="-o" />
                <content type="string" default="reboot" />
                <shortdesc lang="en">Fencing Action</shortdesc>
        </parameter>
        <parameter name="ipaddr" unique="1" required="1">
                <getopt mixed="-s" />
                <content type="string"  />
                <shortdesc lang="en">IP Address of the Virtualbox Server</shortdesc>
        </parameter>
        <parameter name="login" unique="1">
                <getopt mixed="-u" />
                <content type="string"  />
                <shortdesc lang="en">Login on the hypervisor</shortdesc>
        </parameter>
        <parameter name="port" unique="1">
                <getopt mixed="-p" />
                <content type="string"  />
                <shortdesc lang="en">Guest name (name of the virtual machine in virtualbox)</shortdesc>
        </parameter>
        <parameter name="help" unique="1">
                <getopt mixed="-h" />
                <content type="string"  />
                <shortdesc lang="en">Display help and exit</shortdesc>
        </parameter>
</parameters>
<actions>
        <action name="reboot" />
        <action name="on" />
        <action name="off" />
        <action name="list" />
        <action name="status" />
        <action name="metadata" />
</actions>
</resource-agent>
';
}

sub fail
{
  ($msg) = @_;
  print $msg."\n";
  $t->close if defined $t;
  exit 1;
}

sub fail_usage
{
  ($msg)=@_;
  print STDERR $msg."\n" if $msg;
  print STDERR "Please use '-h' for usage.\n";
  exit 1;
}

sub version
{
  print "1.0.0\n";

  exit 0;
}

sub get_options_stdin
{
    my $opt;
    my $line = 0;
    while( defined($in = <>) )
    {
        $_ = $in;
        chomp;
        # Remove comments
        s/#.*//;

        # strip leading and trailing whitespace
        s/^\s*//;
        s/\s*$//;

        # skip empty lines
        next if /^$/;

        $line+=1;
        $opt=$_;
        next unless $opt;

        ($name,$val)=split /\s*=\s*/, $opt, 2;

        if ( $name eq "" )
        {
           print STDERR "parse error: illegal name in option $line\n";
           exit 2;
        }

        # DO NOTHING -- this field is used by fenced
        elsif ($name eq "agent" ) {}

        elsif ($name eq "ipaddr" )
        {
            $opt_s = $val;
        }
        elsif ($name eq "nodename" || $name eq "port" )
        {
            $opt_g = $val;
        }
        elsif ($name eq "login" )
        {
            $opt_u = $val;
        }
        elsif ($name eq "option" || $name eq "action" )
        {
            $opt_o = $val;
        }
        else
        {
            $ENV{$name} = $val;
        }

    }
}

sub get_status {


        my $cmd = "$sshcmd $opt_u\@$opt_s '$vboxcmd --nologo showvminfo $opt_g | /bin/grep -i state:'";

        print "$pname:$cmd\n";
        open(OUT, '-|', $cmd) or die "$pname:status: $cmd";
        while(<OUT>) {
                print "$pname:status:$_";
                (($status) = /^state:\s+(\w.+\w)\s*\(/oi) && last;
        }

        $status = ($status||'unknown');
        if ($status =~ /running/) {
                $exit = 0
        }
        elsif ($status =~ /powered off/) {
                $exit = 2
        }
        else {
                $exit = 1
        }

        return $exit;
}

sub action {
        my $cmd;

        if ($opt_o =~ /^list$/oi) {
                $cmd = "$sshcmd $opt_u\@$opt_s $vboxcmd --nologo list vms | sed -e 's/\"//g' | awk '{print \$1}'";
                open(OUT, '-|', $cmd) or die "$pname:$opt_o: $cmd";
                while(<OUT>) {print "$_"}
                $exit = 0;
                exit ($exit);
        }

        if ($opt_o =~ /^monitor$/oi) {
            exit(0);
        }
        # 0 running, 2 off, 1 erreur
        $status=get_status();

        if ($exit == 1) {
            print "$pname: Can\'t perform status\n";
            exit 1;
        }

        if ($opt_o =~ /^on$/oi) {
                if ($status != 0)       {
                        $cmd = "$sshcmd $opt_u\@$opt_s '$vboxcmd --nologo startvm $opt_g --type headless'";
                        print "$pname:$cmd\n";
                        open(OUT, '-|', $cmd) or die "$pname:$opt_o: $cmd";
                        while(<OUT>) {print "$pname:$_"}
                        sleep 1;
                }
                $exit = 0;
        }
        elsif ($opt_o =~ /^off$/oi) {

                if ($status == 0)       {
                        $cmd = "$sshcmd $opt_u\@$opt_s '$vboxcmd --nologo controlvm $opt_g poweroff'";
                        print "$pname:$cmd\n";
                        open(OUT, '-|', $cmd) or die "$pname:$opt_o: $cmd";
                        while(<OUT>) {print "$pname:$_"}
                }
                $exit = 0;
        }
        elsif ($opt_o =~ /^reboot$/oi) {
                if ($host eq $opt_g){
                        exit(0);
                }

                if ($status ==0 )       {
                        $cmd = "$sshcmd $opt_u\@$opt_s '$vboxcmd --nologo controlvm $opt_g reset'";
                }
                else {
                        $cmd = "$sshcmd $opt_u\@$opt_s '$vboxcmd --nologo startvm $opt_g --type headless'";
                }
                print "$pname:$cmd\n";
                open(OUT, '-|', $cmd) or die "$pname:$opt_o: $cmd";
                while(<OUT>) {print "$pname:$_"}
                sleep 1;
                $exit = 0;
        }
        else {
            die {print "$pname:Unknown action=$opt_o\n"}
        }

        return $exit;
}

######################################################################33
# MAIN

if (@ARGV > 0) {
    GetOptions("s=s"=>\$opt_s,
               "g=s"=>\$opt_g,
               "p=s"=>\$opt_g,
               "o=s"=>\$opt_o,
               "u=s"=>\$opt_u,
               "v"  =>\$opt_V,
               "version"  =>\$opt_V,
               "help"  =>\$opt_h,
               "h"  =>\$opt_h) || fail_usage;
    foreach (@ARGV) {
        print "$_\n";
    }

   usage if defined $opt_h;
   version if defined $opt_V;

   fail_usage "Unknown parameter." if (@ARGV > 0);

} else {
    get_options_stdin();
}

if ((defined $opt_o) && ($opt_o =~ /metadata/i)) {
    print_metadata();
    exit 0;
}

$opt_o=lc($opt_o);
fail "failed: unrecognised action: $opt_o"
    unless $opt_o =~ /^(on|off|reboot|status|list|monitor)$/;


exit(action());

# never reach here!
print "$pname: OK: status=$status, exit=$exit\n";


