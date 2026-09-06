<?php
function radicale_language(): array
{
    $language = '';
    foreach (array($_SESSION['language'] ?? '', $_COOKIE['language'] ?? '', $_SERVER['LANGUAGE'] ?? '', $_SERVER['LANG'] ?? '', $_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? '') as $candidate) {
        if ($candidate !== '') {
            $language = strtolower((string) $candidate);
            break;
        }
    }

    $is_danish = strpos($language, 'da') === 0 || strpos($language, 'danish') === 0;

    if ($is_danish) {
        return array(
            'title' => 'Kalender & kontakter (CalDAV/CardDAV)',
            'intro' => 'Din kalender og adressebog bruger samme login som din e-mailkonto (mailadresse og adgangskode). Indtast din mailadresse for at få dine adresser:',
            'mailbox' => 'Mailadresse',
            'submit' => 'Vis mine adresser',
            'invalid' => 'Indtast en gyldig mailadresse, for eksempel alice@example.com.',
            'server' => 'Serveradresse',
            'calendar' => 'Kalenderadresse',
            'addressbook' => 'Adressebogsadresse',
            'username' => 'Brugernavn',
            'manager' => 'Åbn kalendermanager',
            'share_title' => 'Del en kalender',
            'share_1' => 'Åbn kalendermanageren og log ind med din mailadresse og adgangskode.',
            'share_2' => 'Åbn kalenderens delingsindstillinger og tilføj den anden mailadresse.',
            'share_3' => 'Brug den nøjagtige mailadresse på dit domæne, og gem delingen.',
            'share_4' => 'Den anden bruger åbner manageren, vælger Indgående delinger og accepterer delingen.',
            'share_5' => 'Aktivér og vis delingen, hvis disse muligheder vises, og opdatér derefter kalenderlisten.',
            'share_note' => 'Delinger er skrivebeskyttede som standard. Begge brugere skal bruge deres mailadresser og adgangskoder; DirectAdmin-adgangskoder bruges ikke.',
            'app_note' => 'De fleste apps skal kun bruge serveradressen samt dit brugernavn og din adgangskode. De finder automatisk kalenderen og adressebogen via /.well-known/caldav og /.well-known/carddav. Første forbindelse opretter dem, hvis de ikke findes endnu.',
            'admin_title' => 'Radicale CalDAV/CardDAV',
            'admin_intro' => 'Dette plugin giver hver mailkonto (<code>user@domain.tld</code>) en CalDAV/CardDAV-konto, som godkendes direkte mod Dovecot med samme login som e-mailen.',
            'admin_users' => 'Slutbrugere',
            'admin_users_text' => 'DirectAdmin-brugere finder deres kalender- og kontaktadresser under fanen Kalender & kontakter.',
            'admin_reference' => 'Administratorreference',
            'admin_config' => 'Radicale-konfiguration',
            'admin_storage' => 'Lager til samlinger',
            'admin_service' => 'Tjeneste',
            'admin_cleanup' => 'Oprydnings-hook',
            'admin_proxy' => 'Reverse proxy',
        );
    }

    return array(
        'title' => 'Calendar & Contacts (CalDAV/CardDAV)',
        'intro' => 'Your calendar and address book use the same login as your email account (mailbox address + mail password). Enter your mailbox address below to get your URLs:',
        'mailbox' => 'Mailbox address',
        'submit' => 'Show my URLs',
        'invalid' => 'Enter a valid mailbox address, for example alice@example.com.',
        'server' => 'Server address',
        'calendar' => 'Calendar URL',
        'addressbook' => 'Address book URL',
        'username' => 'Username',
        'manager' => 'Open calendar manager',
        'share_title' => 'Share a calendar',
        'share_1' => 'Open the calendar manager and sign in with your mailbox address and mail password.',
        'share_2' => "Open your calendar's sharing controls and add the other mailbox address.",
        'share_3' => 'Use the exact mailbox address on your domain and save the share.',
        'share_4' => 'The other user opens the manager, selects Incoming Shares, and accepts the share.',
        'share_5' => 'They enable and unhide the share if those options are shown, then refresh their calendar list.',
        'share_note' => 'Shares are read-only by default. Both users must use their mailbox addresses and mail passwords; DirectAdmin passwords are not used.',
        'app_note' => "Most apps only need the server address plus your username/password -- they'll discover the calendar and address book automatically via /.well-known/caldav and /.well-known/carddav. First connection creates them if they don't exist yet.",
        'admin_title' => 'Radicale CalDAV/CardDAV',
        'admin_intro' => 'This plugin gives every mailbox (<code>user@domain.tld</code>) a CalDAV/CardDAV account, authenticated directly against Dovecot with the same login as email.',
        'admin_users' => 'End users',
        'admin_users_text' => 'Regular DirectAdmin users find their calendar and contact URLs under their own Calendar & Contacts tab.',
        'admin_reference' => 'Admin reference',
        'admin_config' => 'Radicale config',
        'admin_storage' => 'Collections storage',
        'admin_service' => 'Service',
        'admin_cleanup' => 'Cleanup hook',
        'admin_proxy' => 'Reverse proxy',
    );
}
