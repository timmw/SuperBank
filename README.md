# SuperBank #

## About

This is a bank plugin for amxmodx which allows players to create a bank account 
which they can deposit and withdraw from in-game. The plugin requires a mysql 
database.

**Please note that this plugin hasn't been officially released and therefore isn't
ready for use in the real world yet!**

## Cvars

    *bank_offrounds - how many rounds before players can withdraw money (default 3)
    *bank_withdrawlimit - how much a player can withdraw in a round

## Commands

    */openaccount<p>Opens a new account, if the player has already opened an account they will be shown a message informing them they already have an account.</p>
    */balance<p>Displays the player's balance in player chat to that player.</p>
    */moneywithdrawn<p>Shows the player how much they have withdrawn so far this round</p>
    */maxdep<p>Deposits all of the player's cash into their account.</p>
    */maxwit<p>Withdraws the maximum amount of cash a player can hold until either they have $16k, they reach their limit for that round or they have no money left in the account.<p>
    *maxdep (console)<p>Same as /maxdep, intended for binding to a key.</p>
    *maxwit (console)<p>Same as /maxwit, intended for binding to a key.</p>
    */withdraw &lt;amout&gt;<p>Withdraws &lt;amount&gt; from the player's account, works in a similar way to /maxwit regarding limits such as balance, money space and money per round limit.</p>
    */deposit &lt;amount&gt;<p>Deposit &lt;amount&gt;.</p>

## Installation

    1.Create a mysql database and assign a user to it with all privileges
    2.Upload the files to the appropriate places
    3.Edit the superbank.cfg file
    4.Make sure you fill in sql.cfg (included with amx) with your database details
    5.Add superbank.amxx into plugins.ini
    6.Restart your server

## Future improvements

    *menu
    *rich list to see richest players
    *lottery
    *donations