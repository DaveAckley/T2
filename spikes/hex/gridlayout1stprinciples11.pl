#!/usr/bin/perl -w

# A tile is a rect
# a rect is [x,y,w,h]
# a grid is a list of tiles ordered by number
# a tileset is a hash of tilenumbers => 1
# a intinfo is [intrect, locknum, tileset]
# a ints is a hash from string intersection rect to intinfo
# a intset is a hash from tile-internal-insectionrect to intinfo
# a tileinfo is hash from tilenum => [tilenumber, intset]

my $TILE_WIDTH = 200;
my $TILE_HEIGHT = 100;
my $GRID_WIDTH = 3;
my $GRID_HEIGHT = 3;
my $EVENT_WINDOW_RADIUS = 4;
my $STAGGER = 0;

my $HORIZONTAL_PITCH = $TILE_WIDTH;
my $VERTICAL_PITCH = $TILE_HEIGHT;
my $FULL_TILE_WIDTH = $TILE_WIDTH + 2*$EVENT_WINDOW_RADIUS;
my $FULL_TILE_HEIGHT = $TILE_HEIGHT + 2*$EVENT_WINDOW_RADIUS;

my @gridTiles;         # list of grid-space rects 
my %gridTileNumbers;   # string grid rect => tile# (index in gridTiles)
my %ints;              # string grid intersection rect => [grect, locknum, hash?]
my %tileInfo;
my %tileLocks;         # tilenumber => count of locks
my %intToDir;          # string internal rect => nominal direction representing it

main();

sub makeRect {
    my ($x,$y,$w,$h) = @_;
    return [$x,$y,$w,$h];
}

sub equalRects {
    my ($r1,$r2) = @_;
    for (my $i = 0; $i < 4; ++$i) {
        return 0 if $r1->[$i] != $r2->[$i];
    }
    return 1;
}

sub printRect {
    print stringRect(shift);
}

sub stringRect {
    my $r = shift;
    return sprintf("Rect(%d,%d,%d,%d)", $r->[0],$r->[1],$r->[2],$r->[3]);
}

sub max {
    my ($a,$b) = @_;
    return $a if $a >= $b;
    return $b;
}

sub min {
    my ($a,$b) = @_;
    return $a if $a <= $b;
    return $b;
}

sub rectArea {
    my $r = shift;
    return $r->[2] * $r->[3];
}

sub intersectRects {
    my $int = shift;
    while (defined (my $other = shift)) {
        my ($xi,$yi,$wi,$hi) = @{$int};
        my ($xo,$yo,$wo,$ho) = @{$other};
        my $xr = max($xi,$xo);
        my $yr = max($yi,$yo);
        my $exr = min($xi+$wi,$xo+$wo);
        my $eyr = min($yi+$hi,$yo+$ho);
        my $wr = max(0, $exr - $xr);
        my $hr = max(0, $eyr - $yr);
        $int = [$xr,$yr,$wr,$hr]
    }
    return $int;
}
# my $t1 = makeRect(-10,20,30,33);
# my $t2 = makeRect(10,25,30,40);
# printRect($t1);print "\n";
# printRect($t2);print "\n";
# my $t3 = intersectRects($t1);
# my $t4 = intersectRects($t3,$t2);
# printRect($t3);print "\n";
# printRect($t4);printf("=%d",rectArea($t4));print "\n";

sub makeGrid {
    for (my $y = 0; $y < $GRID_HEIGHT; ++$y) {
        for (my $x = 0; $x < $GRID_WIDTH; ++$x) {
            my $stag = ($STAGGER ? (($y&1) * $TILE_WIDTH / 2) : 0);
            my $tr = makeRect($HORIZONTAL_PITCH*$x+$stag,$VERTICAL_PITCH*$y,$FULL_TILE_WIDTH,$FULL_TILE_HEIGHT);
            $gridTileNumbers{stringRect($tr)} = scalar(@gridTiles);
            push @gridTiles, $tr;
        }
    }
}

sub stringTile {
    my $tr = shift;
    my $sr = stringRect($tr);
    my $tn = getTileNumber($tr);
    return "#$tn:$sr";
}


sub getTileNumber {
    my $tr = shift;
    my $sr = stringRect($tr);
    my $tn = $gridTileNumbers{$sr};
    die unless defined $tn;
    return $tn;
}

sub mapRectIntoRect {
    my ($in,$out) = @_;
    die unless equalRects($in,intersectRects($in,$out));
    return makeRect($in->[0]-$out->[0],$in->[1]-$out->[1],
                    $in->[2], $in->[3]);
}

sub analyzeDir {
    my $r = shift;
    my ($x,$y,$w,$h) = @{$r};
    my $HALF_FULL_WIDTH = $TILE_WIDTH / 2 + 2 * $EVENT_WINDOW_RADIUS;
    if ($x == 0 && $y == 0) {
        return "N" if $w == $FULL_TILE_WIDTH;
        return "NW" if $w == $HALF_FULL_WIDTH;
        return "NW" if $w == 2*$EVENT_WINDOW_RADIUS && $h == 2*$EVENT_WINDOW_RADIUS;
        return "W" if $w == 2*$EVENT_WINDOW_RADIUS;
    } elsif ($x == 0 && $y == $TILE_HEIGHT) {
        return "SW" if $w == $HALF_FULL_WIDTH;
        return "SW" if $w == 2*$EVENT_WINDOW_RADIUS && $h == 2*$EVENT_WINDOW_RADIUS;
        return "S" if $w == $FULL_TILE_WIDTH;
    } elsif ($x == $TILE_WIDTH / 2 && $y == 0) {
        return "NE" if $w == $HALF_FULL_WIDTH;
    } elsif ($x == $TILE_WIDTH && $y == 0) {
        return "E" if $h == $FULL_TILE_HEIGHT;
        return "NE" if $w == 2*$EVENT_WINDOW_RADIUS && $h == 2*$EVENT_WINDOW_RADIUS;
    } elsif ($x == $TILE_WIDTH / 2 && $y == $TILE_HEIGHT) {
        return "SE" if $w == $HALF_FULL_WIDTH;
    } elsif ($x == $TILE_WIDTH && $y == $TILE_HEIGHT) {
        return "SE" if $w == 2*$EVENT_WINDOW_RADIUS && $h == 2*$EVENT_WINDOW_RADIUS;
    }
    return "ad($x,$y,$w,$h)";
}

sub mapIntsToTiles {
    foreach my $k (sort keys %ints) {
        my $int = $ints{$k}->[0];
        my $lockNum = $ints{$k}->[1];
        my @ts = sort keys %{$ints{$k}->[2]};
        foreach my $tn (@ts) {
            my $tile = $gridTiles[$tn];
            my $intr = mapRectIntoRect($int, $tile);
            my $sintr = stringRect($intr);
            $intToDir{$sintr} = [$intr, analyzeDir($intr)];
            $tileInfo{$tn} = [$tn, {}] unless defined $tileInfo{$tn};
            $tileInfo{$tn}->[1]->{$sintr} = [$int, $lockNum, $ints{$k}];
#            print "$tn $sintr=$lockNum\n";
        }
    }
}

sub drawDpic {
    print ".PS\n";
    foreach my $s (@gridTiles) {
        my $tn = getTileNumber($s);
        my $color = sprintf('"#%02x%02x%02x%02x"',0x88,$tn*25,128+($tn-3)*20,255-$tn*25);
        my ($x,$y,$w,$h) = @{$s}; # full tile
        print "box width $w height $h with .sw at ($x,$y) shaded $color\n";
        my ($ox,$oy,$ow,$oh) = 
            ($x+$EVENT_WINDOW_RADIUS,
             $y+$EVENT_WINDOW_RADIUS,
             $w-2*$EVENT_WINDOW_RADIUS,
             $h-2*$EVENT_WINDOW_RADIUS);
        #print "box width $ow height $oh with .sw at ($ox,$oy) outline \"#88ffff00\"\n";

        #print "Tile[".getTileNumber($s)."]: box stringTile($s)."\n";
    }
    print ".PE\n";
}

sub lesserTile {
    my ($r1, $r2) = @_;
    my $rret;
    if ($r1->[0] < $r2->[0]) {
        $rret = $r1;
    } elsif ($r1->[0] > $r2->[0]) {
        $rret = $r1;
    } elsif ($r1->[1] < $r2->[1]) {
        $rret = $r1;
    } elsif ($r1->[1] > $r2->[1]) {
        $rret = $r2;
    } else { die; }
    return getTileNumber($rret);
}
sub computeIntersections {
    foreach my $s (@gridTiles) {
        foreach my $r (@gridTiles) {
            next if equalRects($s,$r);
            my $int = intersectRects($r,$s);
            next unless rectArea($int);
            my $key = stringRect($int);
            if (!defined($ints{$key})) {
                my $lockOwningTile = lesserTile($s,$r);
                $tileLocks{$lockOwningTile} = 0 unless defined $tileLocks{$lockOwningTile};
                my $tilelocknum = $tileLocks{$lockOwningTile}++;
                my $lockNum = scalar(keys %ints);
                $ints{$key} = [$int, "tiles[$lockOwningTile].lock[$tilelocknum]", {}] unless defined $ints{$key};
            }
            ${$ints{$key}->[2]}{getTileNumber($s)} = 1;
            ${$ints{$key}->[2]}{getTileNumber($r)} = 1;
        }
    }
}

sub printResults {
    foreach my $k (sort keys %ints) {
        my @ts = sort keys %{$ints{$k}->[2]};
        print "$k -> (".scalar(@ts).") ".join(", ",@ts)."\n";
    }
}

sub printDirInfo {
    foreach my $sintr (sort keys %intToDir) {
        print "$sintr -> ".$intToDir{$sintr}->[1]."\n";
    }
}

sub printTileInfo {
    foreach my $tn (sort keys %tileInfo) {
        my $val = $tileInfo{$tn};
        my ($tnum, $intset) = @{$val};
        my ($gx,$gy,$gw,$gh) = @{$gridTiles[$tn]};
        print "\n";
        foreach my $sintr (sort keys %{$intset}) {
            my $intinfo = $intset->{$sintr};
            my ($intr, $locknum, $tileset) = @{$intinfo};
            my $dir = $intToDir{$sintr}->[1];
            my ($extr, $ln2, $hsh) = @{$tileset};
            print " tiles[$tn].LockRegion(Dirs::$dir, $locknum);\n";
            my @otiles = sort keys %{$hsh};
            foreach my $otile (@otiles) {
                next if $otile == $tn;
                my ($gox,$goy,$gow,$goh) = @{$gridTiles[$otile]};
                my ($rx,$ry) = ($gox-$gx, $goy-$gy);
                print "    tiles[$tn].Connect(Dirs::$dir, SPoint($rx,$ry), tiles[$otile]);\n";
            }
        }
    }
}

sub main {
    makeGrid();
    computeIntersections();
    mapIntsToTiles();
    printDirInfo();
    printTileInfo();
#    printResults();
#    drawDpic();
}
