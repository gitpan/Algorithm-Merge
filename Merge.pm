package Algorithm::Merge;

use Algorithm::Diff ();
use Carp;
use strict;
#use Data::Dumper;

use vars qw(@EXPORT_OK @ISA $VERSION $REVISION);

$VERSION = '0.01';

$REVISION = (qw$Revision: 1.6 $)[-1];

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
use constant CB_C =>  3;  # not used in calculations
use constant CB_B =>  5;  # not used in calculations

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

    my $b_len = scalar(@{$bdoc});
    my $c_len = scalar(@{$cdoc});
    my $target_len = $b_len < $c_len ? $b_len : $c_len;
    my $bc_different_lengths = $b_len != $c_len;

    my(@bdoc_save, @cdoc_save);

    my $ab = Algorithm::Diff::diff( $adoc, $bdoc, $keyGen, @_);
    my $ac = Algorithm::Diff::diff( $adoc, $cdoc, $keyGen, @_);

    my %diffs = (
        AB_A , [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '-' } ( map { @{$_} } @{$ab} ) ) ) ],
        AB_B , [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '+' } ( map { @{$_} } @{$ab} ) ) ) ],
        AC_A , [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '-' } ( map { @{$_} } @{$ac} ) ) ) ],
        AC_C , [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '+' } ( map { @{$_} } @{$ac} ) ) ) ],
    );

    undef $ab; undef $ac;  # free memory

    if($bc_different_lengths) {
        
        my $bc = Algorithm::Diff::diff( $bdoc, $cdoc, $keyGen, @_);
        my $cb = Algorithm::Diff::diff( $cdoc, $bdoc, $keyGen, @_);

        #print Data::Dumper -> Dump([$bc]);

        @diffs{(BC_B, BC_C)} = (
            [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '-' } ( map { @{$_} } @{$bc} ) ) ) ],
            [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '+' } ( map { @{$_} } @{$bc} ) ) ) ],
        );
        @diffs{(CB_C, CB_B)} = (
            [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '-' } ( map { @{$_} } @{$cb} ) ) ) ],
            [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '+' } ( map { @{$_} } @{$cb} ) ) ) ],
        );

        if(join(",", @{$diffs{&CB_B}}) ne join(",", @{$diffs{&BC_B}}) ||
           join(",", @{$diffs{&CB_C}}) ne join(",", @{$diffs{&BC_C}}))
        {
            @bdoc_save = splice @{$bdoc}, $target_len;
            @cdoc_save = splice @{$cdoc}, $target_len;
            $bc = Algorithm::Diff::diff( $bdoc, $cdoc, $keyGen, @_);
            
            carp "Algorithm::Diff::diff is not symmetric for second and third sequences - results might not be correct";
        }

        @diffs{(BC_B, BC_C)} = (
            [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '-' } ( map { @{$_} } @{$bc} ) ) ) ],
            [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '+' } ( map { @{$_} } @{$bc} ) ) ) ],
        );

        if(scalar(@bdoc_save) || scalar(@cdoc_save)) {
            push @{$diffs{&BC_B}}, ($target_len .. $b_len) if $target_len < $b_len;
            push @{$diffs{&BC_C}}, ($target_len .. $c_len) if $target_len < $c_len;
        
            push @{$bdoc}, @bdoc_save; undef @bdoc_save;
            push @{$cdoc}, @cdoc_save; undef @cdoc_save;
        }
    }
    else {
        my $bc = Algorithm::Diff::diff( $bdoc, $cdoc, $keyGen, @_);
        @diffs{(BC_B, BC_C)} = (
            [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '-' } ( map { @{$_} } @{$bc} ) ) ) ],
            [ sort { $a <=> $b } ( map { $_ -> [1] } ( grep { $_ -> [0] eq '+' } ( map { @{$_} } @{$bc} ) ) ) ],
        );
    }

    my @pos;
    @pos[A, B, C] = (0, 0, 0);

    my @sizes;
    @sizes[A, B, C] = ( scalar(@{$adoc}), scalar(@{$bdoc}), scalar(@{$cdoc}) );

    my @matches;
    $#matches = 32;

    my $callback = 0;

    my $noop = sub { };

# Callback_Map is indexed by the sum of AB_A, AB_B, ..., as indicated by @matches
# this isn't the most efficient, but it's a bit easier to maintain and 
# read than if it were broken up into separate arrays
# more than half the entries are not $noop - it would see then that no 
# entries should be $noop.  I need patters to figure out what the 
# other entries are.

    my @Callback_Map = (
      [ $no_change,     A, B, C ], # 0  - no matches
      [ $noop,                  ], # 1  -                          BC_C
      [ $b_diff,           B    ], #*2  -                     BC_B
      [ $noop,                  ], # 3  -                     BC_B BC_C
      [ $noop,                  ], # 4  -                AC_C
      [ $c_diff,              C ], # 5  -                AC_C      BC_C
      [ $noop,                  ], # 6  -                AC_C BC_B
      [ $noop,                  ], # 7  -                AC_C BC_B BC_C
      [ $a_diff,        A       ], # 8  -           AC_A
      [ $noop,                  ], # 9  -           AC_A           BC_C
      [ $c_diff,        A, B    ], # 10 -           AC_A      BC_B
      [ $c_diff,        A, B,   ], # 11 -           AC_A      BC_B BC_C
      [ $noop,                  ], # 12 -           AC_A AC_C
      [ $noop,                  ], # 13 -           AC_A AC_C      BC_C
      [ $c_diff,        A, B,   ], # 14 -           AC_A AC_C BC_B
      [ $c_diff,        A, B, C ], # 15 -           AC_A AC_C BC_B BC_C
      [ $noop,                  ], # 16 -      AB_B
      [ $noop,                  ], # 17 -      AB_B                BC_C
      [ $noop,                  ], # 18 -      AB_B           BC_B
      [ $noop,                  ], # 19 -      AB_B           BC_B BC_C
      [ $a_diff,           B, C ], # 20 -      AB_B      AC_C
      [ $noop,                  ], # 21 -      AB_B      AC_C      BC_C
      [ $noop,                  ], # 22 -      AB_B      AC_C BC_B
      [ $conflict,      A, B, C ], # 23 -      AB_B      AC_C BC_B BC_C
      [ $b_diff,           B    ], # 24 -      AB_B AC_A
      [ $noop,                  ], # 25 -      AB_B AC_A           BC_C
      [ $noop,                  ], # 26 -      AB_B AC_A      BC_B
      [ $noop,                  ], # 27 -      AB_B AC_A      BC_B BC_C
      [ $noop,                  ], # 28 -      AB_B AC_A AC_C
      [ $noop,                  ], # 29 -      AB_B AC_A AC_C      BC_C
      [ $noop,                  ], # 30 -      AB_B AC_A AC_C BC_B
      [ $noop,                  ], # 31 -      AB_B AC_A AC_C BC_B BC_C
      [ $no_change,     A, B, C ], # 32 - AB_A
      [ $b_diff,        A,    C ], # 33 - AB_A                     BC_C
      [ $noop,                  ], # 34 - AB_A                BC_B
      [ $b_diff,        A,    C ], # 35 - AB_A                BC_B BC_C
      [ $noop,                  ], # 36 - AB_A           AC_C
      [ $noop,                  ], # 37 - AB_A           AC_C      BC_C
      [ $noop,                  ], # 38 - AB_A           AC_C BC_B
      [ $noop,                  ], # 39 - AB_A           AC_C BC_B BC_C
      [ $a_diff,        A,      ], # 40 - AB_A      AC_A
      [ $noop,                  ], # 41 - AB_A      AC_A           BC_C
      [ $a_diff,        A       ], # 42 - AB_A      AC_A      BC_B
      [ $noop,                  ], # 43 - AB_A      AC_A      BC_B BC_C
      [ $noop,                  ], # 44 - AB_A      AC_A AC_C
      [ $noop,                  ], # 45 - AB_A      AC_A AC_C      BC_C
      [ $noop,                  ], # 46 - AB_A      AC_A AC_C BC_B
      [ $noop,                  ], # 47 - AB_A      AC_A AC_C BC_B BC_C
      [ $noop,                  ], # 48 - AB_A AB_B
      [ $b_diff,        A,    C ], # 49 - AB_A AB_B                BC_C
      [ $noop,                  ], # 50 - AB_A AB_B           BC_B
      [ $a_diff,        A, B, C ], # 51 - AB_A AB_B           BC_B BC_C
      [ $noop,                  ], # 52 - AB_A AB_B      AC_C
      [ $noop,                  ], # 53 - AB_A AB_B      AC_C      BC_C
      [ $noop,                  ], # 54 - AB_A AB_B      AC_C BC_B
      [ $noop,                  ], # 55 - AB_A AB_B      AC_C BC_B BC_C
      [ $noop,                  ], # 56 - AB_A AB_B AC_A
      [ $noop,                  ], # 57 - AB_A AB_B AC_A           BC_C
      [ $noop,                  ], # 58 - AB_A AB_B AC_A      BC_B
      [ $noop,                  ], # 59 - AB_A AB_B AC_A      BC_B BC_C
      [ $noop,                  ], # 60 - AB_A AB_B AC_A AC_C
      [ $noop,                  ], # 61 - AB_A AB_B AC_A AC_C      BC_C
      [ $noop,                  ], # 62 - AB_A AB_B AC_A AC_C BC_B
      [ $conflict,      A, B, C ], # 63 - AB_A AB_B AC_A AC_C BC_B BC_C
    );

    my $t; # temporary values

    # while we have something to work with...
    while((grep { scalar(@{$_}) > 0 } values %diffs) 
          && (grep { $pos[$_] < $sizes[$_] } (A, B, C))) 
    {

        @matches[AB_A, AB_B, AC_A, AC_C, BC_B, BC_C] = undef;

        foreach my $i (A, B, C) {
            foreach my $j (A, B, C) {
                next if $i == $j;
                $t = $abc_s[($i|$j) * 8 | $i];
                $matches[$t] = 1 if @{$diffs{$t}} && $pos[$i] == $diffs{$t} -> [0];
            }
        }
   
        $callback = 0;
        $callback |= $_ foreach grep { $matches[$_] } ( AB_A, AB_B, AC_A, AC_C, BC_B, BC_C );

        my @args = @{$Callback_Map[$callback]};
        my $f = shift @args;
        #warn "callback: $callback - \@pos: ", join(", ", @pos[A, B, C]), "\n";
        #warn "  matches: ", join(", ", @matches[AB_A, AB_B, AC_A, AC_C, BC_B, BC_C]), "\n";
        #warn " diffs: ", join(", ", map { $diffs{$_}->[0] } (AB_A, AB_B, AC_A, AC_C, BC_B, BC_C)), "\n";
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

            my $match = $switch;
            $switch = ( 0, 5, 24, 17, 34, 8, 10, 0 )[$switch];
        #warn "callback: $switch - \@pos: ", join(", ", @pos[A, B, C]), "\n";
        #warn "  match: $match\n";
            &{$Callback_Map[$switch][0]}(@args)
                if $Callback_Map[$switch];
        }
}

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
        #print "op: ", $h -> [0];
        if($h -> [0] eq 'c') { # conflict
            push @{$conflict[0]}, $h -> [2] if defined $h -> [2];
            push @{$conflict[1]}, $h -> [3] if defined $h -> [3];
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
        #print " : ", join(" ", @ret), " [$$h[1],$$h[2],$$h[3]]\n";
    }

    if(wantarray) {
        return @ret;
    }
    return \@ret;
}

#
# For testing:
#
#print join(" ", merge(
#    {
#        CONFLICT => sub ($$) { (
#            q{<}, @{$_[0]}, q{|}, @{$_[1]}, q{>}
#        ) },
#    },
#)), "\n";
#print join(" ", @{
#  }), "\n";


1;

__END__

=head1 NAME

Algorithm::Merge - Three-way merge and diff

=head1 SYNOPSIS

 use Algorithm::Merge qw(merge diff3);

 @merged = merge(\@ancestor, \@a, \@b, { 
               CONFLICT => sub { } 
           });

 @merged = merge(\@ancestor, \@a, \@b, { 
               CONFLICT => sub { } 
           }, $key_generation_function);

 $merged = merge(\@ancestor, \@a, \@b, { 
               CONFLICT => sub { } 
           });

 $merged = merge(\@ancestor, \@a, \@b, { 
               CONFLICT => sub { } 
           }, $key_generation_function);

 @diff   = diff3(\@ancestor, \@a, \@b);

 @diff   = diff3(\@ancestor, \@a, \@b, $key_generation_function);

 $diff   = diff3(\@ancestor, \@a, \@b);

 $diff   = diff3(\@ancestor, \@a, \@b, $key_generation_function);

 @trav   = traverse_sequences3(\@ancestor, \@a, \@b, { 
               # callbacks
           });

 @trav   = traverse_sequences3(\@ancestor, \@a, \@b, { 
               # callbacks
           }, $key_generation_function);

 $trav   = traverse_sequences3(\@ancestor, \@a, \@b, { 
               # callbacks
           });

 $trav   = traverse_sequences3(\@ancestor, \@a, \@b, { 
               # callbacks
           }, $key_generation_function);


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

=head2 traverse_sequences3

This is the workhorse function that goes through the three sequences 
and calls the callback functions.

The following callbacks are supported.

=over 4

=item NO_CHANGE

This is called if all three sequences have the same element at the 
current position.  The arguments are the current positions within each 
sequence, the first argument being the current position within the 
first sequence.

=item A_DIFF

This is called if the first sequence is different than the other two 
sequences at the current position.
This callback will be called with one, two, or three arguments.

If one argument, then only the element at the given position from the 
first sequence is not in either of the other two sequences.

If two arguments, then there is no element in the first sequence that 
corresponds to the elements at the given positions in the second and 
third sequences.

If three arguments, then the element at the given position in the first 
sequence is different than the corresponding element in the other two 
sequences, but the other two sequences have corresponding elements.

=item B_DIFF

This is called if the second sequence is different than the other two 
sequences at the current position.
This callback will be called with one, two, or three arguments.   

If one argument, then only the element at the given position from the 
second sequence is not in either of the other two sequences.

If two arguments, then there is no element in the second sequence that 
corresponds to the elements at the given positions in the first and 
third sequences.

If three arguments, then the element at the given position in the second 
sequence is different than the corresponding element in the other two 
sequences, but the other two sequences have corresponding elements.

=item C_DIFF

This is called if the third sequence is different than the other two 
sequences at the current position.
This callback will be called with one, two, or three arguments.   

If one argument, then only the element at the given position from the 
third sequence is not in either of the other two sequences.

If two arguments, then there is no element in the third sequence that 
corresponds to the elements at the given positions in the first and 
second sequences.

If three arguments, then the element at the given position in the third 
sequence is different than the corresponding element in the other two 
sequences, but the other two sequences have corresponding elements.

=item CONFLICT

This is called if all three sequences have different elements at the 
current position.  The three arguments are the current positions within 
each sequence.

=back 4

=head1 BUGS

Most assuredly there are bugs.  If a pattern similar to the above 
example does not work, send it to <jsmith@cpan.org> or report it on 
<http://rt.cpan.org/>, the CPAN bug tracker.

L<Algorithm::Diff|Algorithm::Diff>'s implementation of C<diff> is not 
symmetric with respect to the input sequences if the second and third 
sequence are of different lengths.  Because of this, 
C<traverse_sequences3> will calculate the diffs of the second and third 
sequences as passed and swapped.  If the differences are not the same, 
it will issue an `Algorithm::Diff::diff is not symmetric for second 
and third sequences...' warning.  It will try to handle this, but there 
may be some cases where it can't.

=head1 SEE ALSO

L<Algorithm::Diff>.

=head1 AUTHOR

James G. Smith, <jsmith@cpan.org>

=head1 COPYRIGHT

Copyright (C) 2003  Texas A&M University.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
