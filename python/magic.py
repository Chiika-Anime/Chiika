from subprocess import Popen, PIPE
import os
import argparse

# parser = argparse.ArgumentParser(description='Pull and push for all Chiika repositories');
# parser.add_argument('--pull', help='pull',action='store_true');
# parser.add_argument('--push', help='push',action='store_true');
#
# args = parser.parse_args();
# pull = args.pull;
# push = args.push;

git_command_fetch_origin            = ['git', 'fetch','origin']
git_command_merge                   = ['git','merge','FETCH_HEAD']
git_command_submodule_init          = ['git','submodule','init']
git_command_submodule_update        = ['git','submodule','update','--recursive']
chiika  = os.getcwd() + "/../";
chiikaApi   = os.getcwd() + "/../lib/ChiikaApi";

print chiika
print chiikaApi
def Create_Dark_Magic():
    print "Creating magic.."
    print "Mixing tomes..."
    git_query = Popen(git_command_fetch_origin, cwd=chiika, stdout=PIPE, stderr=PIPE)
    (git_status, error) = git_query.communicate()
    print "Creating staff of wizardy..."
    git_query = Popen(git_command_merge, cwd=chiika, stdout=PIPE, stderr=PIPE)
    (git_status, error) = git_query.communicate()
    print "Merging dark particles.."
    git_query = Popen(git_command_submodule_init, cwd=chiika, stdout=PIPE, stderr=PIPE)
    (git_status, error) = git_query.communicate()
    print "Using sacred stones.."
    git_query = Popen(git_command_submodule_update, cwd=chiika, stdout=PIPE, stderr=PIPE)
    (git_status, error) = git_query.communicate()

    print "Receiving flux of dark magic.."
    git_query = Popen(git_command_submodule_init, cwd=chiikaApi, stdout=PIPE, stderr=PIPE)
    (git_status, error) = git_query.communicate()
    git_query = Popen(git_command_submodule_update, cwd=chiikaApi, stdout=PIPE, stderr=PIPE)
    (git_status, error) = git_query.communicate()

    print "Igniting fire particles.."
    git_query = Popen(git_command_submodule_init, cwd=chiikaApi + "/ChiikaAPI/ThirdParty/log4cplus", stdout=PIPE, stderr=PIPE)
    (git_status, error) = git_query.communicate()
    git_query = Popen(git_command_submodule_update, cwd=chiikaApi + "/ChiikaAPI/ThirdParty/log4cplus", stdout=PIPE, stderr=PIPE)
    (git_status, error) = git_query.communicate()

    print "Magic ready."

Create_Dark_Magic()
