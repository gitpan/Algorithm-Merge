package Algorithm::Merge;

use Algorithm::Diff ();
use Carp;
use strict;
#use Data::Dumper;

use vars qw(@EXPORT_OK @ISA $VERSION $REVISION);

$VERSION = '0.00_01';

$REVISION = (qw$Revision: 1.1 $)[-1];

@EXPORT_OK = qw(diff3 merge traverse_sequences3);

@ISA = qw(Exporter);

sub diff3 {
    my $pivot             = shift;                                  # array ref
    my $doca              = shift;                                  # array ref
    my $docb              = shift;                                  # array ref
    my $keyGen            = shift;

    my @ret;

    my $no_change = sub {
        push @ret, [ 'u', $pivot -> [$_[0]], $doca -> [$_[1]], $docb -> [$_[2]] ];
    };

    my $conflict = sub {
        my($a, $b, $c);
        $a = $pivot -> [$_[0]] if defined $_[0];
        $b = $doca -> [$_[1]] if defined $_[1];
        $c = $docb -> [$_[2]] if defined $_[2];
        push @ret, [ 'c', $a, $b, $c ];
    };

    my $diff_a = sub {
        if(@_ == 1) {
            push @ret, [ 'o', $pivot -> [$_[0]], undef, undef ];
        }
        elsif(@_ == 2) {
            push @ret, [ 'o', undef, $doca -> [$_[0]], $docb -> [$_[1]] ];
        }
        else {
            push @ret, [ 'o', $pivot -> [$_[0]], $doca -> [$_[1]], $docb -> [$_[2]] ];
        }
    };

    my $diff_b = sub {
        if(@_ == 1) {
            push @ret, [ 'l', undef, $doca -> [$_[0]], undef ];
        }
        elsif(@_ == 2) {
            push @ret, [ 'l', $pivot -> [$_[0]], undef, $docb -> [$_[1]] ];
        }
        else {
            push @ret, [ 'l', $pivot -> [$_[0]], $doca -> [$_[1]], $docb -> [$_[2]] ];
        }
    };

    my $diff_c = sub {
        if(@_ == 1) {
            push @ret, [ 'r', undef, undef, $docb -> [$_[0]] ];
        }
        elsif(@_ == 2) {
            push @ret, [ 'r', $pivot -> [$_[0]], $doca -> [$_[0]], undef ];
        }
        else {
            push @ret, [ 'r', $pivot -> [$_[0]], $doca -> [$_[1]], $docb -> [$_[2]] ];
        }
    };

    traverse_sequences3(
        $pivot, $doca, $docb, 
        {
            NO_CHANGE => $no_change,
            A_DIFF  => $diff_a,
            B_DIFF  => $diff_b,
            C_DIFF   => $diff_c,
            CONFLICT  => $conflict,
        }, 
        $keyGen, @_
    );

    if(wantarray) {
        return @ret;
    }
    else {
        return \@ret;
    }
}

use constant A => 4;
use constant B => 2;
use constant C => 1;

use constant AB_A => 32;
use constant AB_B => 16;
use constant AC_A =>  8;
use constant AC_C =>  4;
use constant BC_B =>  2;
use constant BC_C =>  1;

my @abc_s;
$abc_s[(A|B)*8+A] = AB_A;
$abc_s[(A|B)*8+B] = AB_B;
$abc_s[(A|C)*8+A] = AC_A;
$abc_s[(A|C)*8+C] = AC_C;
$abc_s[(B|C)*8+B] = BC_B;
$abc_s[(B|C)*8+C] = BC_C;

sub traverse_sequences3 {
    my $adoc      = shift;                                  # array ref
    my $bdoc      = shift;                                  # array ref
    my $cdoc      = shift;                                  # array ref
    my $callbacks = shift || {};
    my $keyGen    = shift;
    my $a_diff     = $callbacks->{'A_DIFF'} || sub { };
    my $b_diff     = $callbacks->{'B_DIFF'} || sub { };
    my $c_diff     = $callbacks->{'C_DIFF'} || sub { };
    my $no_change = $callbacks->{'NO_CHANGE'} || sub { };
    my $conflict  = $callbacks->{'CONFLICT'} || sub { };

    my $ab = Algorithm::Diff::diff( $adoc, $bdoc, $keyGen, @_);
    my $ac = Algorithm::Diff::diff( $adoc, $cdoc, $keyGen, @_);
    my $bc = Algorithm::Diff::diff( $bdoc, $cdoc, $keyGen, @_);

    my %diffs = (
        AB_A , [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '-' } ( map { @{$_} } @{$ab} ) ) ) ],
        AB_B , [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '+' } ( map { @{$_} } @{$ab} ) ) ) ],
        AC_A , [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '-' } ( map { @{$_} } @{$ac} ) ) ) ],
        AC_C , [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '+' } ( map { @{$_} } @{$ac} ) ) ) ],
        BC_B , [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '-' } ( map { @{$_} } @{$bc} ) ) ) ],
        BC_C , [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '+' } ( map { @{$_} } @{$bc} ) ) ) ],
    );

    my @pos;
    @pos[A, B, C] = (0, 0, 0);

    my @sizes;
    @sizes[A, B, C] = ( scalar(@{$adoc}), scalar(@{$bdoc}), scalar(@{$cdoc}) );

    my @matches;
    $#matches = 32;

    my $callback = 0;

    my $noop = sub { 
    };

    my @Callback_Map = (
      [ $no_change,     A, B, C ], # 0
      [ $conflict,  undef, B, C ], # 1
      [ $conflict,  A, B, undef ], # 2
      [ $noop,                  ], # 3
      [ $conflict,  A, B, undef ], # 4
      [ $c_diff,              C ], # 5
      [ $noop,                  ], # 6
      [ $noop,                  ], # 7
      [ $a_diff,    A           ], # 8
      [ $noop,                  ], # 9
      [ $c_diff,        A, B    ], # 10
      [ $c_diff,        A, B,   ], # 11
      [ $noop,                  ], # 12
      [ $noop,                  ], # 13
      [ $c_diff,        A, B,   ], # 14
      [ $c_diff,        A, B, C ], # 15
      [ $conflict,  A, B, undef ], # 16
      [ $a_diff,           B, C ], # 17
      [ $b_diff,           B    ], # 18
      [ $c_diff,        A, B    ], # 19
      [ $a_diff,           B, C ], # 20
      [ $noop,                  ], # 21
      [ $noop,                  ], # 22
      [ $noop,                  ], # 23
      [ $b_diff,           B    ], # 24
      [ $noop,                  ], # 25
      [ $noop,                  ], # 26
      [ $noop,                  ], # 27
      [ $noop,                  ], # 28
      [ $conflict,  undef, B, C ], # 29
      [ $noop,                  ], # 30
      [ $noop,                  ], # 31
      [ $no_change,     A, B, C ], # 32
      [ $b_diff,        A,    C ], # 33
      [ $a_diff,        A       ], # 34
      [ $b_diff,        A,    C ], # 35
      [ $b_diff,        A,    C ], # 36
      [ $noop,                  ], # 37
      [ $noop,                  ], # 38
      [ $conflict,  A, undef, C ], # 39
      [ $a_diff,        A,      ], # 40
      [ $noop,                  ], # 41
      [ $noop,                  ], # 42
      [ $noop,                  ], # 43
      [ $c_diff,        A, B    ], # 44
      [ $noop,                  ], # 45
      [ $noop,                  ], # 46
      [ $noop,                  ], # 47
      [ $conflict,  A, B, undef ], # 48
      [ $b_diff,        A,    C ], # 49
      [ $noop,                  ], # 50
      [ $a_diff,        A, B, C ], # 51
      [ $a_diff,           B, C ], # 52
      [ $noop,                  ], # 53
      [ $noop,                  ], # 54
      [ $noop,                  ], # 55
      [ $noop,                  ], # 56
      [ $noop,                  ], # 57
      [ $conflict,  A, B, undef ], # 58
      [ $noop,                  ], # 59
      [ $b_diff,        A, B, C ], # 60
      [ $noop,                  ], # 61
      [ $noop,                  ], # 62
      [ $conflict,      A, B, C ], # 63
    );

    my $t; # temporary values

    # while we have something to work with...
    while((grep { scalar(@{$_}) > 0 } values %diffs) 
          && (grep { $pos[$_] < $sizes[$_] } (A, B, C))) 
    {

        @matches[AB_A, AB_B, AC_A, AC_C, BC_B, BC_C] = 0;

        foreach my $i (A, B, C) {
            foreach my $j (A, B, C) {
                next if $i == $j;
                $t = $abc_s[($i|$j) * 8 | $i];
                $matches[$t] = 1 if @{$diffs{$t}} && $pos[$i] == $diffs{$t} -> [0];
            }
        }
   
#     32   16    8    4    2    1
#    AB_A AB_B AC_A AC_C BC_B BC_C
#  0                               => no change [a|b|c]
#  1                             x => conflict [|b|c]
#  2                        x      => conflict [a|b|]
#  4                   x           => conflict [a|b|]
#  5                   x         x => c, no a or b [||c]  - c different (+)
#  7                   x    x    x => 
#  8              x                => conflict [a||c]
# 10              x         x      => a=b, no c [a|a|]    - c different (-)
# 11              x         x    x =>  (14, b<->a) [|b|c] - a different (0)
# 14              x    x    x      => no b, a==c? [a||c]  - b different (0)
# 15              x    x    x    x => a=b, a!=c b!=c [a|a|c] - c different (.)
# 16         x                     => conflict [a|b|]
# 17         x                   x => b=c, no a [|b|b]   - a different (-)
# 18         x              x      => b, no a or c [|b|] - b different
# 19         x              x    x => b==a, no c [a|a|] - c different (0)
# 20         x         x           => no a, b==c [|b|b] - a different (0)
# 24         x    x                => b, no a or c [|b|] - b different (+)
# 29         x    x    x         x => c!=b, no a [|b|c]  - conflict
# 33    x                        x => 20 (a<->b) no b, a==c, [a||a] - b different (0)
# 34    x                   x      => a, no b or c [a||] - a different (+)
# 35    x                   x    x => a==c, no b [a||a] - b different (0)
# 36    x              x           => a=c, no b [a||a]  - b different (-)
# 39    x              x    x    x => a!=c, no b [a||c] - conflict
# 40    x         x                => a different, no b or c
# 44    x         x    x           =>  (14, b<->c)
# 48    x    x                     => a!=b, no c [a|b]  - conflict (?)
# 49    x    x                   x => a==c, no b [a||a] - b different (0)
# 52    x    x         x           => b==c, no a [|b|b] - a different (0)
# 51    x    x              x    x => b=c, a!=b a!=c [a|b|b] - a different (.)
# 58    x    x    x         x      => a!=b, no c [a|b|]   - conflict
# 60    x    x    x    x           => a=c, a!=b b!=c [a|b|a] - b different (.)
# 63    x    x    x    x    x    x => conflict [a|b|c]   - conflict

        $callback = 0;
        $callback |= $_ foreach grep { $matches[$_] } ( AB_A, AB_B, AC_A, AC_C, BC_B, BC_C );

        my @args = @{$Callback_Map[$callback]};
        my $f = shift @args;
        #warn "callback: $callback - \@pos: ", join(", ", @pos[A, B, C]), "\n";
        #warn "  matches: ", join(", ", @matches[AB_A, AB_B, AC_A, AC_C, BC_B, BC_C]), "\n";
        #warn "args: ", join(", ", map { (qw(- C B - A))[$_] } @args), "\n";
        &{$f}(@pos[@args]);
        foreach (@args) {
            $pos[$_]++;
            if($_ eq A) {
                shift @{$diffs{&AB_A}} if $matches[AB_A];
                shift @{$diffs{&AC_A}} if $matches[AC_A];
            } elsif($_ eq B) {
                shift @{$diffs{&AB_B}} if $matches[AB_B];
                shift @{$diffs{&BC_B}} if $matches[BC_B];
            } elsif($_ eq C) {
                shift @{$diffs{&AC_C}} if $matches[AC_C];
                shift @{$diffs{&BC_C}} if $matches[BC_C];
            }
        }
        last unless @args;
    }

    my $switch;
    my @args;

        while(grep { $pos[$_] < $sizes[$_] } (A, B, C)) {
            $switch = 0;
            @args = ();
            foreach my $i (A, B, C) {
                if($pos[$i] < $sizes[$i]) {
                    $switch |= $i;
                    push @args, $pos[$i]++;
                }
            }
#-
#C        5
#B       24
#B C     17
#A        8
#A C     36
#A B     10
#A B C   0
            my $match = $switch;
            $switch = ( 0, 5, 24, 17, 34, 8, 10, 0 )[$switch];
        #warn "callback: $switch - \@pos: ", join(", ", @pos[A, B, C]), "\n";
        #warn "  match: $match\n";
            &{$Callback_Map[$switch][0]}(@args)
                if $Callback_Map[$switch];
        }
}

#print join(" ", merge(
#    [qw(a         b c b f b d)],
#    [qw(      r   b c b     d b e)],
#    [qw(  l       b c b     d)],
#    #[qw(< l | r > b c b     d b e)],
#    {
#        CONFLICT => sub ($$) { (
#            q{<}, @{$_[0]}, q{|}, @{$_[1]}, q{>}
#        ) },
#    },
#)), "\n";
#print join(" ", @{
#    [qw(< r | l > b c b     d b e)],
#    #[qw(< l | r > b c b     d b e)],
#  }), "\n";

# a b < c d e h i | e f g i > j k
# a b d e h < | g > i j k

#my $diff = diff3(
#traverse_sequences3(
# [qw(a b c   e f   h i   k)],
## [qw(a b   d e f g   i j k)],
# [qw(a b c d e     h i j k)],
#);

#foreach my $h (@{$diff}) {
#    print $h -> [0], " [ ", join(" | ", @{$h}[1 .. 3]), "]\n";
#}



sub merge {
    my $pivot             = shift;                                  # array ref
    my $doca              = shift;                                  # array ref
    my $docb              = shift;                                  # array ref
    my $callbacks         = shift || {};
    my $keyGen            = shift;

    my $conflictCallback  = $callbacks -> {'CONFLICT'} || sub ($$) { (
        q{<!-- ------ START CONFLICT ------ -->},
        (@{$_[0]}),
        q{<!-- ---------------------------- -->},
        (@{$_[1]}),
        q{<!-- ------  END  CONFLICT ------ -->},
    ) };

    my $diff = diff3($pivot, $doca, $docb, $keyGen, @_);

#    print Data::Dumper -> Dump([$diff]), "\n";

    my @ret;

    my @conflict = ( [], [] );

    foreach my $h (@{$diff}) {
        my $i = 0;
#        print "op: ", $h -> [0];
        if($h -> [0] eq 'c') { # conflict
            push @{$conflict[0]}, $h -> [2] if defined $h -> [2];
            push @{$conflict[1]}, $h -> [3] if defined $h -> [3];
            #push @ret, &$conflictCallback($h -> [2], $h -> [3]);
        }
        else {
            if(@{$conflict[0]} || @{$conflict[1]}) {
                push @ret, &$conflictCallback(@conflict);
                @conflict = ( [], [] );
            }
            if($h -> [0] eq 'u') { # unchanged
                push @ret, $h -> [2] || $h -> [3];
            }
            elsif($h -> [0] eq 'o') { # added
                push @ret, $h -> [2] if defined $h -> [2];
            }
            elsif($h -> [0] eq 'l') { # added by left
                push @ret, $h -> [2] if defined $h -> [2];
            }
            elsif($h -> [0] eq 'r') { # added by right
                push @ret, $h -> [3] if defined $h -> [3];
            }
        }
#        print " : ", join(" ", @ret), " [$$h[1],$$h[2],$$h[3]]\n";
    }

    if(wantarray) {
        return @ret;
    }
    return \@ret;
}

1;

__END__

=head1 NAME

Algorithm::Merge - Three-way merge and diff

=head1 SYNOPSIS

 use Algorithm::Merge qw(merge diff3);

 @merged = merge(\@ancestor, \@a, \@b);

 @merged = merge(\@ancestor, \@a, \@b, $key_generation_function);

 $merged = merge(\@ancestor, \@a, \@b);

 $merged = merge(\@ancestor, \@a, \@b, $key_generation_function);

 @diff   = diff3(\@ancestor, \@a, \@b);

 @diff   = diff3(\@ancestor, \@a, \@b, $key_generation_function);

 $diff   = diff3(\@ancestor, \@a, \@b);

 $diff   = diff3(\@ancestor, \@a, \@b, $key_generation_function);

=head1 USAGE

This module complements L<Algorithm::Diff|Algorithm::Diff> by 
providing three-way merge and diff functions.

In this documentation, the first list to C<diff3> and C<merge> is 
called the `original' list.  The second list is the `left' list.  The 
third list is the `right' list.

The optional key generation arguments are the same as in 
L<Algorithm::Diff|Algorithm::Diff>.  See L<Algorithm::Diff> for more 
information.

=head2 diff3

Given references to three lists of items, C<diff3> performs a 
three-way difference.

This function returns an array of operations describing how the 
left and right lists differ from the original list.  In scalar 
context, this function returns a reference to such an array.

Perhaps an example would be useful.

Given the following three lists,

  original: a b c   e f   h i   k
      left: a b   d e f g   i j k
     right: a b c d e     h i j k

     merge: a b   d e   g   i j k

we have the following result from diff3:

 [ 'u', 'a',   'a',   'a' ],
 [ 'u', 'b',   'b',   'b' ],
 [ 'l', 'c',   undef, 'c' ],
 [ 'o', undef, 'd',   'd' ],
 [ 'u', 'e',   'e',   'e' ],
 [ 'r', 'f',   'f',   undef ], 
 [ 'o', 'h',   'g',   'h' ],
 [ 'u', 'i',   'i',   'i' ],
 [ 'o', undef, 'j',   'j' ],
 [ 'u', 'k',   'k',   'k' ]

The first element in each row is the array with the difference:

 c - conflict (no two are the same)
 l - left is different 
 o - original is different
 r - right is different
 u - unchanged

The next three elements are the lists from the original, left, 
and right arrays respectively that the row refers to (in the synopsis,
these are C<@ancestor>, C<@a>, and C<@b>, respectively).

=head2 merge

Given references to three lists of items, C<merge> performs a three-way 
merge.  The C<merge> function uses the C<diff3> function to do most of 
the work.

The only callback currently used is C<CONFLICT> which should be a 
reference to a subroutine that accepts two array references.  The 
first array reference is to a list of elements from the left list.  
The second array reference is to a list of elements from the right list.
This callback should return a list of elements to place in the merged 
list in place of the conflict.

The default C<CONFLICT> callback returns the following:

 q{<!-- ------ START CONFLICT ------ -->},
 (@left),
 q{<!-- ---------------------------- -->},
 (@right),
 q{<!-- ------  END  CONFLICT ------ -->},

=head1 BUGS

Most assuredly there are bugs.  If a pattern similar to the above 
example does not work, send it to <jsmith@cpan.org> or report it on 
<http://rt.cpan.org/>, the CPAN bug tracker.

=head1 SEE ALSO

L<Algorithm::Diff>.

=head1 AUTHOR

James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2003  Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
