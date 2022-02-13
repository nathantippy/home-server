<?php

/* Local configuration for Roundcube Webmail */

// ----------------------------------

// SQL DATABASE

// ----------------------------------

// Database connection string (DSN) for read+write operations

// Format (compatible with PEAR MDB2): db_provider://user:password@host/database

// Currently supported db_providers: mysql, pgsql, sqlite, mssql, sqlsrv, oracle

// For examples see http://pear.php.net/manual/en/package.database.mdb2.intro-dsn.php

// Note: for SQLite use absolute path (Linux): 'sqlite:////full/path/to/sqlite.db?mode=0646'

//       or (Windows): 'sqlite:///C:/full/path/to/sqlite.db'

// Note: Various drivers support various additional arguments for connection,

//       for Mysql: key, cipher, cert, capath, ca, verify_server_cert,

//       for Postgres: application_name, sslmode, sslcert, sslkey, sslrootcert, sslcrl, sslcompression, service.

//       e.g. 'mysql://roundcube:@localhost/roundcubemail?verify_server_cert=false'

$config['db_dsnw'] = 'pgsql://roundcube:${PG_PASS}@localhost/roundcubemail';

// ----------------------------------

// IMAP

// ----------------------------------

// The IMAP host chosen to perform the log-in.

// Leave blank to show a textbox at login, give a list of hosts

// to display a pulldown menu or set one host as string.

// Enter hostname with prefix ssl:// to use Implicit TLS, or use

// prefix tls:// to use STARTTLS.

// Supported replacement variables:

// %n - hostname ($_SERVER['SERVER_NAME'])

// %t - hostname without the first part

// %d - domain (http hostname $_SERVER['HTTP_HOST'] without the first part)

// %s - domain name after the '@' from e-mail address provided at login screen

// For example %n = mail.domain.tld, %t = domain.tld

// WARNING: After hostname change update of mail_host column in users table is

//          required to match old user data records with the new host.

$config['default_host'] = '${TF-DOMAIN}';

// ----------------------------------

// SMTP

// ----------------------------------

// SMTP server host (for sending mails).

// Enter hostname with prefix ssl:// to use Implicit TLS, or use

// prefix tls:// to use STARTTLS.

// Supported replacement variables:

// %h - user's IMAP hostname

// %n - hostname ($_SERVER['SERVER_NAME'])

// %t - hostname without the first part

// %d - domain (http hostname $_SERVER['HTTP_HOST'] without the first part)

// %z - IMAP domain (IMAP hostname without the first part)

// For example %n = mail.domain.tld, %t = domain.tld

// To specify different SMTP servers for different IMAP hosts provide an array

// of IMAP host (no prefix or port) and SMTP server e.g. ['imap.example.com' => 'smtp.example.net']

// ${TF-DOMAIN}';  'localhost';

$config['smtp_server'] = 'localhost';

// 25 on localhostt
$config['smtp_port'] = 587;
//465;

// provide an URL where a user can get support for this Roundcube installation

// PLEASE DO NOT LINK TO THE ROUNDCUBE.NET WEBSITE HERE!

$config['support_url'] = '';

// This key is used for encrypting purposes, like storing of imap password

// in the session. For historical reasons it's called DES_key, but it's used

// with any configured cipher_method (see below).

// For the default cipher_method a required key length is 24 characters.

$config['des_key'] = '3uKtsGWe17OgbIp3JJhRrSOf';

// Automatically add this domain to user names for login

// Only for IMAP servers that require full e-mail addresses for login

// Specify an array with 'host' => 'domain' values to support multiple hosts

// Supported replacement variables:

// %h - user's IMAP hostname

// %n - hostname ($_SERVER['SERVER_NAME'])

// %t - hostname without the first part

// %d - domain (http hostname $_SERVER['HTTP_HOST'] without the first part)

// %z - IMAP domain (IMAP hostname without the first part)

// For example %n = mail.domain.tld, %t = domain.tld

$config['username_domain'] = '${TF-DOMAIN}';
 
// ----------------------------------

// PLUGINS

// ----------------------------------

// List of active plugins (in plugins/ directory)

$config['plugins'] = ['archive', 'attachment_reminder', 'database_attachments', 'emoticons', 'enigma', 'jqueryui', 'password', 'zipdownload'];

// the default locale setting (leave empty for auto-detection)

// RFC1766 formatted language name like en_US, de_DE, de_CH, fr_FR, pt_BR

$config['language'] = 'en_US';

// Set the spell checking engine. Possible values:

// - 'googie'  - the default (also used for connecting to Nox Spell Server, see 'spellcheck_uri' setting)

// - 'pspell'  - requires the PHP Pspell module and aspell installed

// - 'enchant' - requires the PHP Enchant module

// - 'atd'     - install your own After the Deadline server or check with the people at http://www.afterthedeadline.com before using their API

// Since Google shut down their public spell checking service, the default settings

// connect to http://spell.roundcube.net which is a hosted service provided by Roundcube.

// You can connect to any other googie-compliant service by setting 'spellcheck_uri' accordingly.

// $con fig['spellcheck_engine'] = 'atd';

$config['enable_installer'] = true;



