<h1>SuperBank</h1>

<h2>About</h2>

This is a bank plugin for amxmodx which allows players to create a bank account 
which they can deposit and withdraw from in-game. The plugin requires a mysql 
database.

<b>Please note that this plugin hasn't been officially released and therefore isn't
ready for use in the real world yet!<b>

<h2>Cvars</h2>

<ul>

    <li>bank_offrounds - how many rounds before players can withdraw money (default 3)</li>
    <li>bank_withdrawlimit - how much a player can withdraw in a round</li>

</ul>

<h2>Commands</h2>

<ul>

    <li>/openaccount<p>Opens a new account, if the player has already opened an account they will be shown a message informing them they already have an account.</p></li>
    <li>/balance<p>Displays the player's balance in player chat to that player.</p></li>
    <li>/moneywithdrawn<p>Shows the player how much they have withdrawn so far this round</p></li>
    <li>/maxdep<p>Deposits all of the player's cash into their account.</p></li>
    <li>/maxwit<p>Withdraws the maximum amount of cash a player can hold until either they have $16k, they reach their limit for that round or they have no money left in the account.<p></li>
    <li>maxdep (console)<p>Same as /maxdep, intended for binding to a key.</p></li>
    <li>maxwit (console)<p>Same as /maxwit, intended for binding to a key.</p></li>
    <li>/withdraw &lt;amout&gt;<p>Withdraws &lt;amount&gt; from the player's account, works in a similar way to /maxwit regarding limits such as balance, money space and money per round limit.</p></li>
    <li>/deposit &lt;amount&gt;<p>Deposit &lt;amount&gt;.</p></li>

</ul>

<h2>Installation</h2>

<ol>

    <li>Create a mysql database and assign a user to it with all privileges</li>
    <li>Upload the files to the appropriate places</li>
    <li>Edit the superbank.cfg file</li>
    <li>Make sure you fill in sql.cfg (included with amx) with your database details</li>
    <li>Add superbank.amxx into plugins.ini</li>
    <li>Restart your server</li>

</ol>

<h2>Future improvements</h2>

<ul>

    <li>menu</li>
    <li>rich list to see richest players</li>
    <li>lottery</li>
    <li>donations</li>

</ul>