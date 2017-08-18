# Freenom automatic domain registration program

This is a program that automate free domain registration at http://www.freenom.com
in order for it to work you will need the following

* perl
* an account with freenom.com, with ALL your details filled in
* a cool idea for a domain name for one of the following tld's tk,ml,ga,cf or gq

## How does it work

The program got 2 functionalities, "check" and "register" and is invoked from the
commandline in one of the following ways:

```
./freenom.pl check mynewdomain <username> <password>
./freenom.pl check mynewdomain.ml <username> <password>
./freenom.pl register mynewdomain.ml <username> <password>

```

In check mode, the domain can be the domain name minus the tld, in order to search for
the domain in all the free tld's offered by freenom, of it can be the fully qualified
domain name such as: myawesomedomain.ml

In register mode you specify the full domain including tld.

In both modes you specify your freenom username and password.



