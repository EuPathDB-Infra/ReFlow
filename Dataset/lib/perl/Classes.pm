package ReFlow::Dataset::Classes;

use strict;

use XML::Simple;
use Data::Dumper;
use ReFlow::DataSource::DataSources;

sub new {
  my ($class, $classesFile) = @_;

  my $self = {classesFile => $classesFile};

  bless($self,$class);

  $self->{xml} = new XML::Simple();

  $self->_parseXmlFile($classesFile);

  return $self;
}

sub validateClassName {
  my ($self, $className) = @_;

  return $self->{data}->{datasetClass}->{$className};
}

# get list of plans used
sub getPlan2Classes {
    my ($self, $classNamesUsed) = @_;
    my %plan2classes;
    foreach my $className (@$classNamesUsed) {
      my $planFile = $self->{data}->{datasetClass}->{$className}->{graphFile}->{planFile};
      push(@{$plan2classes{$planFile}}, $className) if $planFile;
    }
    return \%plan2classes;
}

sub getClass {
    my ($self, $className) = @_;
    my $class = $self->{data}->{datasetClass}->{$className};
    die "Can't find class with name '$className' in classes file $self->{classesFile}\n" unless $class;
    return $class;
}

sub getClassGraphFileDir {
    my ($self, $className) = @_;
    my $class = $self->getClass($className);
    return $class->{graphFile}->{dir};
}

sub getResourceText {
    my ($self, $dataset) = @_;
    my $class = $self->getClass($dataset->{class});
    my $resource;
    $resource->{resource} = $class->{resource}; # hack a little to outsmart XMLout
    return "" unless $resource->{resource};

    my $rawResourceText = $self->{xml}->XMLout($resource);

    # jump through some hoops to lose weird lines out put by XMLout
    # probably a better way to do this
    my @lines = split(/\n/,$rawResourceText);
    my @lines2;
    foreach my $line (@lines) {
      next if $line =~ /^\<opt/;
      next if $line =~ /^\<\/opt/;
      next if $line =~ /^$/;
      push(@lines2,$line);
    }
    my $rawResourceText2 = join("\n", @lines2);

    my ($resourceText, $err) = substitutePropsIntoXmlText($rawResourceText2, $dataset);
    if ($err) {
	die "Error: in classes file $self->{classesFile}, the <resource> element in class '$dataset->{class}' contains an invalid macro:\n$err\n";
    }
    return "$resourceText\n";
}

# static method
sub substitutePropsIntoXmlText {
    my ($xmlText, $dataset) = @_;

    my $newXmlText = $xmlText;
    foreach my $propKey (keys(%{$dataset->{prop}})) {
#      print STDERR "prop: $propKey\n";
      my $propValue = $dataset->{prop}->{$propKey}->{content};
      $newXmlText =~ s/\$\{$propKey\}/$propValue/g;
    }

    my $err = 0;
    if ($newXmlText =~ /(\$\{.*?\})/) {
	$err = $1;
    }
    return ($newXmlText, $err);
}

sub _parseXmlFile {
  my ($self, $classesFile) = @_;

  # need to force all elements to be an array so that when we 
  # use XMLout to print xml text, they stay as elements
  my $fa = ReFlow::DataSource::DataSources::getForceArray();
  my $forceArray = ['datasetClass','pluginArgs','manualGet', @$fa];
  print STDERR join(" ", @$forceArray);

  $self->{data} = eval{ $self->{xml}->XMLin($classesFile, SuppressEmpty => undef, KeyAttr=>'class', ForceArray=>$forceArray) };

#  print STDERR Dumper $self->{data};
  die "$@\nerror processing classes XML file $classesFile\n" if($@);
}

1;
