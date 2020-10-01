use strict;
use IPC::Open2;
use Data::Dumper;
use JSON;

$|++;

my ($heartInput, $heartOutput);
open2($heartOutput, $heartInput, "node bin\\heart");

while(my $rawJSON = <$heartOutput>) {
    chomp($rawJSON);
    # print("Got: $rawJSON\n");

    my $ev = undef;
    eval {
        $ev = from_json($rawJSON);
    };
    if ($@) {
        print("Bad Event JSON: $rawJSON\n");
        next;
    }

    print("Event: " . Dumper($ev));
    if(($ev->{'type'} eq 'msg') and ($ev->{'chan'} eq 'test_channel_ignore')) {
        my $sev = {
            type => 'msg',
            chan => $ev->{'chan'},
            text => "HEARD: " . $ev->{'text'},
            delay => 0,
        };
        print $heartInput to_json($sev);
        print $heartInput "\n";
    }
}
