use Test;

use Algorithm::Merge qw(diff3 merge);
use Algorithm::Diff qw(diff);
use Data::Dumper;

plan tests => 3;

eval { require Algorithm::Merge; };

ok !$@;

eval { Algorithm::Merge -> import('diff3'); };

ok !$@;

eval { Algorithm::Merge -> import('merge'); };

ok !$@;

exit 0;

