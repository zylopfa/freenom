#!/usr/bin/perl
use LWP;
use LWP::UserAgent;
use HTTP::Cookies;
use URI::Escape;
use JSON qw{ to_json from_json };

my $cookie_jar = HTTP::Cookies->new(
    agent => "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:27.0) Gecko/20100101 Firefox/27.0"
);

my $ua = LWP::UserAgent->new(
    ssl_opts   => { verify_hostname => 0 },
    cookie_jar => $cookie_jar,
);

push @{ $ua->requests_redirectable }, 'POST';

my $method = $ARGV[0];
my $domainTld = $ARGV[1];
my ($domain,$tld) = split /\./,$domainTld;
my $login = $ARGV[2];
my $pass  = $ARGV[3];


unless ( $method =~ m/(check|register)/ && $domainTld && $login && $pass) {usage();}


my $req = HTTP::Request->new(GET => "http://www.freenom.com/en/index.html?lang=en");
my $res = $ua->request($req);

my $loginName = siteLogin($login,$pass);

if ($loginName) {
  print "Successfully logged in as " . $loginName . "\n";
}
else {
  print "Error logging in, check username and password!\n";
  exit 1;
}


if ( $method eq "check" ) {
  usage() unless ($domain);
  my $av = checkDomainAvailability($domain,$tld);

  unless ( scalar(@$av)) {
    print "\nNo domains available $domain.$tld\n";
    exit 0;
  }

  print "\nAvailable domains:\n\n";
  foreach my $d (@$av) {
    print $d->{"domain"} .  $d->{"tld"} . "\n";
  }

  print "\n";

}
elsif ( $method eq "register" ) {
  usage() unless ($domain && $tld =~ m/(tk|ml|ga|cf|gq)/);


  my $av = checkDomainAvailability($domain,$tld);



  unless ( scalar(@$av)) {
    print "\nDomain not available for registration $domain.$tld\n\n";
    exit 0;
  }

  my $isRegistered = registerDomain($domain,$tld);

  if ($isRegistered ) {
     print "\nDomain $domain.$tld registered successfully!\n";
     print "Order number is: " . $isRegistered  . "\n\n";
     print "Remember to setup DNS which point to a webserver,\nor the domain will be lost (freenom policy)\n\n";
  }
  else {
    print "\nERROR: Unable to register the domain!\n";
  }
 
}


sub usage {

  print "\n";
  print "Usage: \n";
  print "\t$0 check mynewdomain <username> <password>\n";
  print "\t$0 check mynewdomain.ml <username> <password>\n";
  print "\t$0 register mynewdomain.ml <username> <password>\n";
  print "\n";

  exit 0;
}

sub registerDomain {
  my $domain = shift;
  my $tld = shift; # one of:  tk,ml,cf,gq

  $req = HTTP::Request->new(POST => "https://my.freenom.com/includes/domains/fn-additional.php");
  $req->header('Referer', 'https://my.freenom.com/domains.php');
  $req->content_type('application/x-www-form-urlencoded');
  $req->content("domain=" . $domain . "&tld=" . uri_escape("." .$tld));

  $res = $ua->request($req);
  $content = $res->content;

  my $avg = from_json($content);

  if ($avg->{"available"} eq "0" ) {
    return 0;
  }

  # this shit always say available 1, check first normally

  $req = HTTP::Request->new(GET => "https://my.freenom.com/cart.php?a=confdomains");
  $res = $ua->request($req);
  $content = $res->content;

  my $token = "";
  if ( $content =~ /name=\"token\".*?value=\"(.*?)\"/)  {
    $token = $1;
  }

  unless ($token) {return 0;}

  $req = HTTP::Request->new(POST => "https://my.freenom.com/includes/domains/confdomain-update.php");
  $req->header('Referer', 'https://my.freenom.com/cart.php?a=confdomains');
  $req->content_type('application/x-www-form-urlencoded');
  $req->content("domain=" . $domain . "." . $tld . "&period=12M");

  $res = $ua->request($req);
  $content = $res->content;

  my $st = from_json($content);
  
  unless ($st->{"status"} eq "OK") {return 0;}

  my $periodName = $domain . "_" . $tld . "_period";


  $req = HTTP::Request->new(POST => "https://my.freenom.com/cart.php?a=confdomains");
  $req->header('Referer', 'https://my.freenom.com/cart.php?a=confdomains');
  $req->content_type('application/x-www-form-urlencoded');
  $req->content("token=" . $token . "&update=true&" . $periodName . "=12M&idprotection[0]=on&domainns1=ns01.freenom.com&" .
	        "domainns2=ns02.freenom.com&domainns3=ns03.freenom.com&domainns4=ns04.freenom.com&domainns5="
  );

  $res = $ua->request($req);
  $content = $res->content;

  my $form = "";

  if ( $content =~ /<form.*?id="mainfrm">(.*?)<\/form>/gis) {
    $form = $1;
  }

  my $keyValues = {};

  if ( $form =~ /name="token" value="(.*?)"/ ) {
    $keyValues->{"token"} = $1;
  }

  while ($form =~ m/(<input.*>)/g) {
    my $inputHtml = $1;

    my $name = "";
    my $value = "";

    if ($inputHtml=~ /name="(.*?)"/) {
      $name = $1;
    }
    if ($inputHtml=~ /value="(.*?)"/) {
      $value = $1;
    }

    if ($name eq "accepttos") { $value="1";}
    if ($name eq "fpbb" ) { $value="0400a7p6X9S/XZwNf94lis1ztioT9A1DShgATTGvKpCeZlRwmEZ+z1fPZRcJnGLiky0W1+WpmjdizJJlHVB6chrI7oZc+cJURcFiYtBUbpa7l0GrVjpSL/tvtZ2bYY09+WmE2HRR5wgRl27DANztcOyFXr///7cbh2IvtCoeN+KAk0KAU1UNOVUCYlOzKIjzY0fFx+6o9j1+mLEsTM/hMBs0vL349852M7BfjNXsgMEghG04JacwCaWoKvPoP5g1QwsR6HPyNaJmTDbHKCbQnNPJNxB05cIr8ixWhCiebBE66IKYqVPGPgk+TlUCyP57qu9lLTQVC0oMSbn+7s6WY27c+e8LY1SVL+nhkvpeYEYecTMAbNrJcwB5jcqK4pvupFpLGqU2RdWsEosJuvK70bwBpHGL9SBAEfPHII83mt6iVsAWiIYYjbEvXCXVTb29yNd9VSVIiz9BgypOZxGfdUz+MN8fRxoNU2oc7NA7EPzZBQS0hmeTUaqhv70SUl5nPtLdk7sCBU58HT4Bn9A1DIoE+AB7Zazj3KJbJHnz6c7uiFUNczN14q3ly0ETe76Xek/N0+1vm3fbD4o44UoglC71q+iLYPrgmlkD3VxmTaKH/RfryXjUEvWNbJ+24uoio9BkmKURjzhBSm3z3wafI/WYHEsTCs2TKRSUB860/YtAXmxIolVMSGqJYKYiJ/+IO4wJIlIuUrTru69iDwK4w63kwurhYKIcxurY1nTsVt9Ji8umJSb8HQiG/PFVqOKNf+iU3WSiFx72DBpGxLglENmIKE581x3FJTsUUE6gTcLs0+XlEA9y66X/SJua7jIHCjHlY0gCNS+IYhc=";}
    if ($name eq "iobb" ) { $value="0400nyhffR+vPCUNf94lis1ztioT9A1DShgATTGvKpCeZlRwmEZ+z1fPZRcJnGLiky0WhxsJ3VO4EPgIzzvOlBUh9qRTaDjmUTl26LEtcYEgIDXyxDKJBqBicYLtctOBy5zszqaGWVDv9cdgO962GbSLFcqAPNKVwml2GkVn5hklpTXQtVCYANQUGR45eVo3JvuI/tdLFIRKIDfdOIOtuynGr2hCOHvr5Xx0WPy/tudaZOuBTvCYfZaHNdxnF72KhuoPujoZ8bICN3/xFYjpJeaAv5VPfVKB9sZJLWwxc10RKdaOhqmbbJ2gAEcGdfH3YZis79hd2kxAKZlcc5FYAtfQjn/4VbP+Nuu/X6t2xsBNqMDIx5G6nzZ9jXlFnBT3M8OkOF6DbL/Bu+7D4TWhv78VEIne56x7fyVRFqHfv6lgZq+NNE4xK4FhMTBnxg3zCYy9LXUch4azZiCquCl2HvhLHszftc7o4yjruZmcL034xXvRffpF5Oo1kU02uExjh+DCcqRRZovoTu4NfyJw5Y9lzPtwK6dBL0wrOVVPyQ4V1oTurKZQptWVuqisQeaPWllnrqOaHscMfxndOIOtuynGr/ybM0o/CKz6+gy4FURAen0lQ0U0H1NKwwl2Y1Y/iacv0I7HurKtMJNm35324i+AlX6G4joXDjSTzZwYPPZOeqxfZIt4GTWL6sw8sWPoZcEZGcsmEc9b0eITndP3sK6wqU3hpIUvhMiiseci1MOaniG3OPuUo3ukRtOtXYtZlAzfpsySOUqPDq7CQai4/k8/K9DvxPQAaf/XuwLLNTE9qpxd7e4/rX4B5JwMc2AnJBy5H5upXMLoYztMIt1EbvMWttrjUufdk/9818BA/5If6JmWSaGJn5pibRBpAFWEgILguYkvsqAad1AFCE1XRfN+HZ21ET4rhaHYJ8gn8kWTU33OJZHmrKYOwA91wcO2q799SbUXZrXdkFbl0wt9PRt24l6qHpLcttv/fFvv3XED48L3SFHKz6Hss4rr+l3H+CrCNeTzei24erIYmiUKdM6p62Kz017LU3hXtETav8R5EkfkPniz9mZVww4tI1bJ11JBRUJy4DNiOYGRL9uc49TuyI1Z9wHwbk+5IQcrBa/Ra00q6Lh+xrniyxygMAO8BpdFTvWVHLH8sjaWt3N41ZXaBA==";}

    $keyValues->{$name} = $value if ($name);
  }  


  my $post = "";

  foreach my $ff ( keys %$keyValues) {
    $post .= $ff . "=" . uri_escape($keyValues->{$ff}) . "&";  
  }

  chop($post);

  $req = HTTP::Request->new(POST => "https://my.freenom.com/cart.php?a=checkout");
  $req->header('Referer', 'https://my.freenom.com/cart.php?a=checkout');
  $req->content_type('application/x-www-form-urlencoded');
  $req->content($post);

  $res = $ua->request($req);
  $content = $res->content;

  if ( $content =~ /Your Order Number is: (\d+)/ ) {
    return $1;
  }
  else {
    return 0;
  }
}



sub checkDomainAvailability {
  my $domain = shift;
  my $tld = shift; # one of:  tk,ml,cf,gq

  $req = HTTP::Request->new(POST => "https://my.freenom.com/includes/domains/fn-available.php");
  $req->header('Referer', 'https://my.freenom.com/domains.php');
  $req->content_type('application/x-www-form-urlencoded');
  $req->content("domain=" . $domain . "&tld=" . $tld);

  $res = $ua->request($req);
  $content = $res->content;

  my $domainAvailability = from_json($content);

  print "TLD:" . $tld ."\n";

#  print $content . "\n";

  my @availableDomains = ();

  if ( $domainAvailability->{"top_domain"}->{"status"} eq "AVAILABLE" && $domainAvailability->{"top_domain"}->{"type"} eq "FREE" && 
       $domainAvailability->{"top_domain"}->{"tld"} =~ /$tld$/ ) {
    push @availableDomains,$domainAvailability->{"top_domain"};
  }

  foreach my $dom ( @{$domainAvailability->{"free_domains"}}) {
    if ( $dom->{"status"} eq "AVAILABLE" && $dom->{"type"} eq "FREE" ) {
      push @availableDomains,$dom unless($tld);
      push @availableDomains,$dom if ($tld && $dom->{"tld"} =~ /$tld$/ );
    }
  }
  return \@availableDomains; 
}



sub siteLogin {
  my $login = shift;
  my $pass = shift;

  # get the token
  my $req = HTTP::Request->new(GET => "https://my.freenom.com/clientarea.php");
  my $res = $ua->request($req);

  my $content = $res->content;

  my $token = "";

  if ( $content =~ /name=\"token\".*?value=\"(.*?)\"/)  {
    $token = $1;
  }

  return 0 unless ($token);

  $req = HTTP::Request->new(POST => "https://my.freenom.com/dologin.php");
  $req->header('Referer', 'https://my.freenom.com/clientarea.php');
  $req->content_type('application/x-www-form-urlencoded');
  $req->content("token=" . $token . "&password=" . uri_escape($pass) . "&username=" . uri_escape($login));

  $res = $ua->request($req);

  $content = $res->content;

  my $name = "";

  if ( $content =~ /<h1 class=\"splash\">Hello (.*?)<\/h1>/ ) {
    $name = $1;
  }

  return 0 unless ($name);
  return $name;
}


