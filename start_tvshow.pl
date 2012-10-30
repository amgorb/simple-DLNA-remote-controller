#!/usr/bin/perl
use Net::UPnP::ControlPoint;
use Net::UPnP::AV::MediaRenderer;
use Net::UPnP::ActionResponse;
use Net::UPnP::AV::MediaServer;
my $DLNAserver = "DLNA"; #regexp name of you local DLNA server 
my $filename = "city"; #regexp for searching filename
my $TVname = 'VIERA'; #DLNA device (TV) must contain this string in name, otherwise it will be skipped

my $stopbeforeplay = 1; #will stop/start TV one time

## END OF CONFIG 
## DO NOT CHANGE BELOW THIS LINE (only if you know what to do :)
## =============================================================
## simple-DLNA-remote-controller

#$Net::UPnP::DEBUG = 1;

sub now {
$now = `date +"%x %T"`;
chomp($now);
$now = $now . " == ";
return $now;
}

$SIG{'INT'} = 'exit_handler';

sub exit_handler () {
  print "Caught CTRL-C!! Cleaning up, terminating. \n";
  ### Do cleanup . kill the children
  if ($c) {
     $c->release();
     $c->remove();
     }
  $SIG{'INT'} = 'DEFAULT';
  exit;
}

print now()."Started. Running search.\n";
my $obj = Net::UPnP::ControlPoint->new();
@dev_list = $obj->search(st =>'upnp:rootdevice', mx => 5);
print now()."Found $#dev_list devices\n";
print now()."Searching for \"$filename\" at all DLNA servers..\n";
foreach $dev (@dev_list) {
     $device_type = $dev->getdevicetype();
     if  ($device_type ne 'urn:schemas-upnp-org:device:MediaServer:1') {
         next;
     }
     unless ($dev->getservicebyname('urn:schemas-upnp-org:service:ContentDirectory:1')) {
         next;
     }
     print now(). "Found ".$dev->getfriendlyname() . "\n";
     if ($dev->getfriendlyname() !~ /$DLNAserver/) {
	next;
     }
    $mediaServer = Net::UPnP::AV::MediaServer->new();
    $mediaServer->setdevice($dev);

    @content_list = $mediaServer->getcontentlist(ObjectID => 0);
    foreach $content (@content_list) {
        find_content($mediaServer, $content, 1);
    }
    my $parentid;
    sub find_content {
        my ($mediaServer, $content, $indent) = @_;
        my $id = $content->getid();
        my $title = $content->gettitle();
        for ($n=0; $n<$indent; $n++) {
        }
        if ($content->isitem()) {
            if (length($content->getdate())) {
            }
        }
	if ($title =~ /$filename/) {
           $file = $content->geturl();
	   $filecontenttype =  $content->getcontenttype();
	   $fileid = $content->getid();
	   $filetitle = $content->gettitle();
	}
        unless ($content->iscontainer()) {
            return;
        }
        @child_content_list = $mediaServer->getcontentlist(ObjectID => $id );
        if (@child_content_list <= 0) {
            return;
        }
        $indent++;
        foreach my $child_content (@child_content_list) {
	    $parentid = $child_content->getid();
            find_content($mediaServer, $child_content, $indent);
        }
    }
}

if ($file) {
     print now()."found $filename at $file\n";
  }
   else { 
  print now()."file $filename not found! Terminating.\n";
  exit(1);
}


use IPC::Semaphore::Concurrency;

while (1) { 

    our $c = IPC::Semaphore::Concurrency->new('/tmp/sem_file');
    if ( $c->acquire(0, 0, -1, 0) ) {
        print now()."Semaphore is free, OK\n";
    } else {
        print now()."Semaphore is busy, probably another instance is running! Will not start, removing semaphore.\n";
	$c->release();
	exit(1);
    }

    print now() . "[!] Starting loop \n";

    my $obj = Net::UPnP::ControlPoint->new();
    @dev_list = ();
    my $retry_cnt = 0;
    while (@dev_list <= 0 ) {
	print now() . "Searching for renderers.. @dev_list\n";
        @dev_list = $obj->search(st =>'urn:schemas-upnp-org:device:MediaRenderer:1', mx => 5);
        $retry_cnt++;
	if ($retry_cnt >= 5) {
	print now() . "[!] No renderers found. Releasing semaphore, exiting.\n";
	$c->release();
        exit(1);
 	}
    }
    print now() . "Found $#dev_list renderers\n"; 
 
    $devNum= 0;
    foreach $dev (@dev_list) {
	my $device_type = $dev->getdevicetype();
        if  ($device_type ne 'urn:schemas-upnp-org:device:MediaRenderer:1') {
            next;
        }

	$devNum++;
        my $friendlyname = $dev->getfriendlyname(); 
        print now() . "found [$devNum] : device name: [" . $friendlyname . "] " ;
	if ($friendlyname !~ /$TVname/) { print "skipping this device.\n";next;}

        my $renderer = Net::UPnP::AV::MediaRenderer->new();
        $renderer->setdevice($dev);
	$condir_service = $dev->getservicebyname('urn:schemas-upnp-org:service:AVTransport:1');
        %action_in_arg = (
                'ObjectID' => 0,
                'InstanceID' => '0'
            );
        $action_res = $condir_service->postcontrol('GetTransportInfo', \%action_in_arg);
        $actrion_out_arg = $action_res->getargumentlist();
	$x = $actrion_out_arg->{'CurrentTransportState'};
	print "Device current state is <<$x>>. ";
        if ( ($x !~ /PLAY/) || ($stopbeforeplay == 1) ) { 
          if ($stopbeforeplay == 1) { 
		print "First run, force stop-start \n";
	    } else {  print "Device is in bad state, starting up! \n"; }
	  } else {
	    print "This is ok, skipping.\n";
	    next;
	    }
        $meta = <<EOF;
&lt;DIDL-Lite xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/&quot; xmlns:dc=&quot;http://purl.org/dc/elements/1.1/&quot; xmlns:upnp=&quot;urn:schemas-upnp-org:metadata-1-0/upnp/&quot;&gt;&lt;item id=&quot;2\$8\$1B&quot; parentID=&quot;2\$15&quot; restricted=&quot;true&quot;&gt;  &lt;dc:title&gt;final_movie&lt;/dc:title&gt;  &lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;  &lt;res protocolInfo=&quot;http-get:*:video/x-msvideo:*&quot; size=&quot;138332664&quot; duration=&quot;2:35:27.079&quot; resolution=&quot;1366x768&quot; bitrate=&quot;6002933&quot; sampleFrequency=&quot;44100&quot; nrAudioChannels=&quot;1&quot;&gt;$file&lt;/res&gt;&lt;/item&gt;&lt;/DIDL-Lite&gt;
EOF
	$id = 0;
        $renderer->setAVTransportURI(InstanceID => $id, CurrentURI => $file, CurrentURIMetaData => $meta);
	my $child=fork();
        if ($child == 0) { #child process
#waiting for semaphore
  	  if ($c->acquire(0,TRUE,-1,0)) { 
	#all good
             } else {
	 #something wrong
               }
	  if ($stopbeforeplay == 1) {
 	    print now() . "device [$devNum] pid $$ command: [stop] \n";
	    $renderer->stop();
	    $stopbeforeplay = 0;
          }
	  print now() . "device [$devNum] pid $$ command: [play] $fileid $file \n";sleep 1;
          $renderer->play(); 
          $devNum++;
	  exit;
	  } else { 
	       push (@childs,$child);
		#PARENT nothing else to do here
          }
    } #for each devices
  print now(). "removing semaphore, mass play all device now.\n";
  $c->release();
  $c->remove();
  $stopbeforeplay = 0;
  sleep 1;
  print now()."waiting for childs to finish.\n";
  for my $pid (@childs) {
  waitpid $pid, 0;
}
 print now(). "finished loop\n";
}#global while ends
