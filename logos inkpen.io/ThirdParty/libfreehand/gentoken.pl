$ARGV0 = shift @ARGV;
$ARGV1 = shift @ARGV;
$ARGV2 = shift @ARGV;
open ( TOKENS, $ARGV0 ) || die "can't open token file: $!";
my %tokens;
while ( defined ($line = <TOKENS>) )
{
    if( !($line =~ /^
    {
        chomp($line);
        @token = split(/\s+/,$line);
        if ( not defined ($token[1]) )
        {
            $token[1] = "FH_".$token[0];
            $token[1] =~ tr/\-\.\:/___/;
            $token[1] =~ s/\+/PLUS/g;
            $token[1] =~ s/\-/MINUS/g;
        }
        $tokens{$token[0]} = uc($token[1]);
    }
}
close ( TOKENS );
open ( HXX, ">$ARGV1" ) || die "can't open tokens.hxx file: $!";
open ( GPERF, ">$ARGV2" ) || die "can't open tokens.gperf file: $!";
print ( GPERF "%language=C++\n" );
print ( GPERF "%global-table\n" );
print ( GPERF "%null-strings\n" );
print ( GPERF "%struct-type\n" );
print ( GPERF "struct fhtoken\n" );
print ( GPERF "{\n" );
print ( GPERF "  const char *name;\n  int tokenId;\n" );
print ( GPERF "};\n" );
print ( GPERF "%%\n" );
print ( HXX "#ifndef __FHTOKENS_HXX__\n" );
print ( HXX "#define __FHTOKENS_HXX__\n" );
print ( HXX "\n" );
$i = 1;
foreach( sort(keys(%tokens)) )
{
    print( HXX "const int $tokens{$_} = $i;\n" );
    print( GPERF "$_,$tokens{$_}\n" );
    $i = $i + 1;
}
print ( GPERF "%%\n" );
print ( HXX "\n" );
print ( HXX "const int FH_TOKEN_COUNT = $i;\n" );
print ( HXX "\n" );
print ( HXX "const int FH_TOKEN_INVALID = -1;\n" );
print ( HXX "\n" );
print ( HXX "#endif\n" );
close ( HXX );
close ( GPERF );
