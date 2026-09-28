const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");


function updateVersionFile(file, version, digest) {
    let lines = [];

    if (fs.existsSync(file)) {
        const content = fs.readFileSync(file, "utf8");

        lines = content
            .split("\n")
            .filter(Boolean);
    }

    let updated = false;
    let found = false;

    lines = lines.map(line => {
        const [oldVersion, oldDigest] = line.split(/\s+/);

        if (oldVersion === version) {
            found = true;

            if (oldDigest !== digest) {
                updated = true;
                return `${version} ${digest}`;
            }

            return line;
        }

        return line;
    });


    // 新版本。
    if (!found) {
        lines.push(`${version} ${digest}`);
        updated = true;
    }

    if (updated) {
        fs.writeFileSync(
            file,
            lines.join("\n") + "\n"
        );

        console.log(`updated ${file}`);
    } else {
        console.log(`unchanged ${file}`);
    }
}


function createPackageIfMissing(packageFile, metadata) {
    if (fs.existsSync(packageFile)) return;

    const packageName = metadata.package_name;
    console.log(`Package ${packageName} does not exist; creating it.`);
    const result = spawnSync("xmake", [
        "create-package",
        packageName,
        JSON.stringify(metadata)
    ], {
        encoding: "utf8"
    });

    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) throw result.error;
    if (result.status !== 0) {
        throw new Error(`xmake create-package failed with status ${result.status}`);
    }
}


async function main() {
    const payload = JSON.parse(process.env.CLIENT_PAYLOAD);
    const packageName = payload.package_name;
    const sourceRepo = payload.repo.split("/");
    const owner = sourceRepo[0];
    const repo = sourceRepo[1];
    const tag = payload.version;
    const version = tag.replace(/^v/, "");

    console.log(
        `Updating ${packageName} ${version}`
    );

    const octokit = require("@octokit/rest");

    const github = new octokit.Octokit({
        auth: process.env.GITHUB_TOKEN
    });


    /*
     * 获取 Release。
     */
    const release =
        await github.rest.repos.getReleaseByTag({
            owner,
            repo,
            tag
        });

    const packageDir = path.join("packages", packageName[0], packageName);
    const packageFile = path.join(packageDir, "xmake.lua");
    const versionDir = path.join(packageDir, "versions");
    let packageChecked = false;

    /*
     * asset 名称映射。
     */
    function getVersionFile(name) {
        if (name.includes("linux-arm64-shared")) return "linux-arm64-shared.txt";
        if (name.includes("linux-arm64-static")) return "linux-arm64-static.txt";
        if (name.includes("linux-x86_64-shared")) return "linux-x86_64-shared.txt";
        if (name.includes("linux-x86_64-static")) return "linux-x86_64-static.txt";
        if (name.includes("windows-x64-MDd-shared")) return "windows-x64-MDd-shared.txt";
        if (name.includes("windows-x64-MDd-static")) return "windows-x64-MDd-static.txt";
        if (name.includes("windows-x64-MD-shared")) return "windows-x64-MD-shared.txt";
        if (name.includes("windows-x64-MD-static")) return "windows-x64-MD-static.txt";

        return null;
    }

    for (const asset of release.data.assets) {
        const versionFile = getVersionFile(asset.name);
        if (!versionFile) continue;

        if (!packageChecked) {
            createPackageIfMissing(packageFile, payload);
            packageChecked = true;
        }

        const digest = asset.digest.replace(
            "sha256:",
            ""
        );

        const file = path.join(
            versionDir,
            versionFile
        );

        const line = `${version} ${digest}\n`;

        updateVersionFile(
            file,
            version,
            digest
        );

        console.log(
            `updated ${file}`
        );
    }
}


main().catch(err => {
    console.error(err);
    process.exit(1);
});
