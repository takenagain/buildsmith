#[cfg(test)]
mod tests {
    use super::super::EnvironmentProfile;

    #[test]
    fn test_environment_profiles() {
        let profiles = EnvironmentProfile::all();
        assert_eq!(profiles.len(), 5);

        let dev_scripts = EnvironmentProfile::Development.get_default_scripts();
        assert!(dev_scripts.contains(&"git.sh"));
        assert!(dev_scripts.contains(&"python.sh"));

        let server_scripts = EnvironmentProfile::Server.get_default_scripts();
        assert!(server_scripts.contains(&"openssh-server.sh"));

        assert_eq!(
            EnvironmentProfile::Development.to_string(),
            "Development Machine"
        );
        assert_eq!(EnvironmentProfile::Server.to_string(), "Server");
    }
}
