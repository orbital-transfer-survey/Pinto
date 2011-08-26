#!perl

use strict;
use warnings;

use Test::File;
use Test::More (tests => 21);

use File::Temp;
use Path::Class;
use FindBin qw($Bin);

use Pinto;
use Pinto::Util;

#------------------------------------------------------------------------------

my $repos     = dir( File::Temp::tempdir(CLEANUP => 1) );
my $pinto     = Pinto->new(out => \my $buffer, repos => $repos);
my $auth_dir  = dir( $Bin, qw(data fakes authors id L LO LOCAL) );
my $dist_file = $auth_dir->file('Foo-Bar-Baz-0.03.tar.gz');

#------------------------------------------------------------------------------
# Creation...

$pinto->new_action_batch();

$pinto->add_action('Create')->run_actions();
repos_file_exists_ok( [qw(config pinto.ini)] );
repos_file_exists_ok( [qw(modules 02packages.details.txt.gz)] );
repos_file_exists_ok( [qw(modules 02packages.details.local.txt.gz)] );
repos_file_exists_ok( [qw(modules 02packages.details.mirror.txt.gz)] );
repos_file_exists_ok( [qw(modules 03modlist.data.gz)] );
repos_file_exists_ok( [qw(authors 01mailrc.txt.gz)] );

#------------------------------------------------------------------------------
# Addition...

# Make sure we have clean slate
index_package_not_exists_ok( 'Foo::Bar::Baz' );
repos_dist_not_exists_ok( 'AUTHOR', $dist_file->basename() );

$pinto->add_action('Add', dist => $dist_file, author => 'AUTHOR');
$pinto->run_actions();

repos_dist_exists_ok( 'AUTHOR', $dist_file->basename() );
index_package_exists_ok('Foo::Bar::Baz', 'AUTHOR', '0.03');

#----

$pinto->add_action('Add', dist => $dist_file, author => 'AUTHOR');
$pinto->run_actions();

like($buffer, qr/same distribution already exists/, 'Cannot add same dist twice');

$pinto->add_action('Add', dist => $dist_file, author => 'CHAUCEY');
$pinto->run_actions();

like($buffer, qr/Only author AUTHOR can update/, 'Cannot add package owned by another author');

$pinto->add_action('Add', dist => 'none_such', author => 'AUTHOR');
$pinto->run_actions();

like($buffer, qr/does not exist/, 'Cannot add nonexistant dist');

#------------------------------------------------------------------------------
# Removal...

$pinto->add_action('Remove', package => 'None::Such', author => 'AUTHOR');
$pinto->run_actions();

like($buffer, qr/is not in the local index/, 'Removing bogus package throws exception');

$pinto->add_action('Remove', package => 'Foo::Bar::Baz', author => 'CHAUCEY');
$pinto->run_actions();

like($buffer, qr/Only author AUTHOR can remove/, 'Cannot remove package owned by another author');

$pinto->add_action('Remove', package => 'Foo::Bar::Baz', author => 'AUTHOR' );
$pinto->run_actions();

repos_dist_not_exists_ok( 'AUTHOR', $dist_file->basename() );
index_package_not_exists_ok( 'Foo::Bar::Baz' );

# Adding again, with different author...
$pinto->add_action('Add', dist => $dist_file, author => 'CHAUCEY');
$pinto->run_actions();

repos_dist_exists_ok( 'CHAUCEY', $dist_file->basename() );

index_package_exists_ok('Foo::Bar::Baz', 'CHAUCEY', '0.03');

#------------------------------------------------------------------------------
# TODO: Refactor these into a Test::* class for testing the repos

sub repos_file_exists_ok {
    my ($path, $name) = @_;
    $path = file( $repos, @{$path} );
    return file_exists_ok($path, $name);
}

sub repos_file_not_exists_ok {
    my ($path, $name) = @_;
    $path = file( $repos, @{$path} );
    return file_not_exists_ok($path, $name);
}

sub repos_dist_exists_ok {
    my ($author, $dist_basename, $name) = @_;
    my $author_dir = Pinto::Util::author_dir($repos, qw(authors id), $author);
    my $dist_path = $author_dir->file($dist_basename);
    return file_exists_ok($dist_path, $name);
}

sub repos_dist_not_exists_ok {
    my ($author, $dist_basename, $name) = @_;
    my $author_dir = Pinto::Util::author_dir($repos, qw(authors id), 'AUTHOR');
    my $dist_path = $author_dir->file($dist_basename);
    return file_not_exists_ok($dist_path, $name);
}

sub index_package_exists_ok {
    my ($name, $author, $version) = @_;
    my $pkg = $pinto->_idxmgr->master_index->packages->{$name};
    return fail("Package $name should be in the index") if not $pkg;

    my $dist = $pkg->dist();
    is($dist->author(), $author,  'Package has correct author');
    is($pkg->version(), $version, 'Package has correct version');
    return 1;
}

sub index_package_not_exists_ok {
    my ($name) = @_;
    my $pkg = $pinto->_idxmgr->master_index->packages->{$name};
    return is(undef, $pkg, "Package $name should not be in the index");
}

#------------------------------------------------------------------------------
