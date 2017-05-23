package dbtest;
use parent 'PGObject::Composite';

sub _get_typename { 'foobar' };
sub _get_typeschema { 'public' };
sub dbh {
    my ($self) = @_;
    return $self->SUPER::dbh(@_) if ref $self;
    return $main::dbh;
}

sub func_prefix {
    return '';
}

sub func_schema {
    return 'public';
}

package main;

use PGObject::Composite;
use Test::More;
use DBI;
use Data::Dumper;

my %hash = (
   foo => 'foo',
   bar => 'baz',
   baz => '2',
   id  => '33',
);

plan skip_all => 'Not set up for db tests' unless $ENV{DB_TESTING};
plan tests => 11;
my $dbh1 = DBI->connect('dbi:Pg:dbname=postgres', 'postgres');
$dbh1->do('CREATE DATABASE pgobject_test_db') if $dbh1;


our $dbh = DBI->connect('dbi:Pg:dbname=pgobject_test_db', 'postgres');
$dbh->do('
   CREATE TYPE foo as ( foo text, bar text, baz int, id int )
   ') if $dbh;

$dbh->do('
   CREATE FUNCTION public.foobar(in_self foo)
      RETURNS int language sql as $$
          SELECT char_length($1.foo) + char_length($1.bar) + $1.baz * $1.id;
      $$;
') if $dbh;

$dbh->do('CREATE SCHEMA test;') if $dbh;

$dbh->do('
   CREATE FUNCTION test.foobar (in_self public.foo)
      RETURNS int language sql as $$
          SELECT 2 * (char_length($1.foo) + char_length($1.bar) + $1.baz * $1.id);
      $$;
') if $dbh;

my $answer = 72;

SKIP: {
   skip 'No database connection', 8 unless $dbh;
   my $obj = dbtest->new(%hash);
   $obj->set_dbh($dbh);
   is($obj->dbh, $dbh, 'DBH set');
   my ($ref) = $obj->call_procedure(
      funcname => 'foobar',
   );
   is ($ref->{foobar}, 159, 'Correct value returned, call_procedure') or diag Dumper($ref);

   ($ref) = PGObject::Composite->call_procedure(
      dbh => $dbh,
      funcname => 'foobar',
      args => ['text', 'text2', '5', '30']
   );
   is ($ref->{foobar}, 159, 'Correct value returned, call_procedure, package invocation') or diag Dumper($ref);

   ($ref) = dbtest->call_procedure(funcname => 'foobar', 
	   args => ['text', 'text2', '5', '30']
   );
   is ($ref->{foobar}, 159, 'Correct value returned, package invocation with factories') or diag Dumper($ref);


   ($ref) = $obj->call_procedure(
      funcname => 'foobar',
      funcschema => 'public',
      args => ['text1', 'text2', '5', '30']
   );

   is ($ref->{foobar}, 160, 'Correct value returned, call_procedure w/schema') or diag Dumper($ref);

   ($ref) = $obj->call_dbmethod(
      funcname => 'foobar'
   );

   is ($ref->{foobar}, $answer, 'Correct value returned, call_dbmethod') or diag Dumper($ref);
   ($ref) = PGObject::Composite->call_dbmethod(
      funcname => 'foobar',
          args => \%hash,
           dbh => $dbh,
   );
   is ($ref->{foobar}, $answer, 'Correct value returned, call_dbmethodi with hash and no ref') or diag Dumper($ref);
       
   ($ref) = dbtest->call_dbmethod(funcname => 'foobar', 
	   args => \%hash
   );
   is ($ref->{foobar}, $answer, 'Correct value returned, package invocation with factories and dbmethod') or diag Dumper($ref);


   ($ref) = $obj->call_dbmethod(
      funcname => 'foobar',
      args     => {id => 4}
   );

   is ($ref->{foobar}, 14, 'Correct value returned, call_dbmethod w/args') or diag Dumper($ref);
   $obj->_set_funcprefix('foo');
   ($ref) = ($ref) = $obj->call_dbmethod(
      funcname => 'bar',
      args     => {id => 4}
   );
   is ($ref->{foobar}, 14, 'Correct value returned, call_dbmethod w/args/prefix') or diag Dumper($ref);
   ($ref) = ($ref) = $obj->call_dbmethod(
      funcname => 'oobar',
      args     => {id => 4},
    funcprefix => 'f'
   );
   is ($ref->{foobar}, 14, 'Correct value returned, call_dbmethod w/exp. pre.') or diag Dumper($ref);

   $obj->_set_funcschema('test');
   $obj->_set_funcprefix('');
   ($ref) = $obj->call_dbmethod(
      funcname => 'foobar'
   );

   is ($ref->{foobar}, $answer * 2, 'Correct value returned, call_dbmethod') or diag Dumper($ref);
   $obh = dbtest->new();

}

$dbh->disconnect if $dbh;
$dbh1->do('DROP DATABASE pgobject_test_db') if $dbh1;
$dbh1->disconnect if $dbh1;
