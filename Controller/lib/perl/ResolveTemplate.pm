package ReFlow::Controller::ResolveTemplate;

use strict;

my $MACROSYM = '&&';

sub resolve {
  my ($xmlFile, $rtcFile, $name) = @_;

  my $templateConfig = parseRtcFile($name, $rtcFile);

  open(XML, $xmlFile) || die "Can't open xml_file '$xmlFile'\n";
  my $newXml;
  while (<XML>) {
    next if /\<workflowGraph/;
    next if /\<\/workflowGraph/;
    die "Error: template XML file may not contain a <templateInstance>\n"
      if /\<templateInstance/;
    die "Error: template XML file may not contain a <templateDepends>\n"
      if /\<templateDepends/;
    $newXml .= substituteTemplateMacros($_, $templateConfig);
  }
  return $newXml;
}


sub parseRtcFile {
  my ($name, $rtcFile) = @_;

  my $config;
  my $found;
  my $done;
  open(RTC, $rtcFile) || die "Can't open rtc_file '$rtcFile'\n";
  while(<RTC>) {
    chomp;
    next if /^\s*$/;
    if (/^\>$name/) {
      die "Error: duplicate stanza for '$name' found\n" if $done;
      $found = 1;
    } elsif ($found && /\/\//) {
      $done = 1;
    } elsif ($found && !$done && /^\>/) {
      die "Error: stanza for '$name' must end in a line with '//'\n";
    } elsif ($found && !$done) {
      /(.*?)\=(.*)/ || die "Error: invalid format on line $. of rtc_file '$rtcFile'\n";
      my $key = $1;
      die "Error: duplicate key '$key' found in stanza for '$name'\n"
	if $config->{$key};
      $config->{$key} = $2;
    }
  }
  return $config;
}

sub substituteTemplateMacros {
  my ($line, $config) = @_;

  return $line unless $line =~ /$MACROSYM/;
  foreach my $key (keys(%$config)) {
    $line =~ s/$MACROSYM$key$MACROSYM/$config->{$key}/g;
  }
  die "Error: can't resolve a template macro in line $. of template xml_file: $line\n" if $line =~ /$MACROSYM/;
  return $line;
}

1;
